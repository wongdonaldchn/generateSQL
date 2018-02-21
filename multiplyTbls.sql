set serveroutput on

----------------------------------------------------------------------------------------------
-- タイプとファンクション
----------------------------------------------------------------------------------------------
create or replace type colArrays as varray(50) of varchar2(500);
/

create or replace function getTblCols(
	tableName in varchar, 					--テーブル名
	extendCols in colArrays,			--増幅対象コラム名リスト
	defaultCols in colArrays				--初期値対象コラム名リスト
)
RETURN varchar
is
	colsWithoutExcluded varchar(5000); --処理後列名
	colName varchar(500); 	-- 列名
	CURSOR colcursor IS SELECT COLUMN_NAME FROM ALL_TAB_COLUMNS WHERE TABLE_NAME=tableName;
begin	

	colsWithoutExcluded := ' ';
	
	dbms_output.put_line('テーブルの列名取得 : ' || tableName);
	
	-- 列名取得
	OPEN colcursor;
		LOOP
			FETCH colcursor INTO colName;
			EXIT WHEN colcursor%notfound;
			--増幅対象コラム排除
			FOR col IN 1..extendCols.COUNT LOOP
				IF (extendCols(col) = colName) THEN
					colName := ' ';
				END IF;
			END LOOP;
			--初期値対象コラム排除
			FOR col IN 1..defaultCols.COUNT LOOP
				IF (defaultCols(col) = colName) THEN
					colName := ' ';
				END IF;
			END LOOP;
			IF (colName = ' ') THEN
				--Do nothing
				NULL;
			ELSIF (colsWithoutExcluded = ' ') THEN
				colsWithoutExcluded := colName;
			ELSE
				colsWithoutExcluded := colsWithoutExcluded || ', ' || colName;
			END IF;
		END LOOP;
	CLOSE colcursor;
	
	--dbms_output.put_line(colsWithoutExcluded);
	
	RETURN colsWithoutExcluded;
end getTblCols;
/

create or replace function getColsWithComma(
	colList in colArrays			--コラム名リスト
)
RETURN varchar
is
	cols varchar(5000); --処理後列名
begin	

	cols := ' ';
	--コンマ連結
	FOR col IN 1..colList.COUNT LOOP
		IF (cols = ' ') THEN
			cols := colList(col);
		ELSE
			cols := cols || ', ' || colList(col);
		END IF;
	END LOOP;
	
	--dbms_output.put_line(cols);
	
	RETURN cols;
end getColsWithComma;
/

create or replace function addQuota(
	inVal in varchar			--入力値
)
RETURN varchar
is
	quote varchar(1);	
	outVal varchar(500);
begin	
	quote := chr(39);

	outVal := quote || inVal || quote;
	
	RETURN outVal;
end addQuota;
/

----------------------------------------------------------------------------------------------
-- プロシージャ
----------------------------------------------------------------------------------------------
--　①単純単独主キーでの倍増共通プロシージャ
----------------------------------------------------------------------------------------------
create or replace procedure doubleTables(
	tableName in varchar, 					-- テーブル名
	pk in varchar,								-- 主キー
	startValue in number					-- 開始値（主キーの開始値を指定する、開始値はテーブルの最大値より小さい場合、テーブルの最大値を用いる）
)
is
	extendCols colArrays;					-- 増幅対象コラム名リスト
	colNames varchar(5000); 			-- 列名
		
	sql_str varchar(20000); 			-- SQL文
	
    currentCnt number;        			-- 現状の総件数
    maxID number;          				-- ID最大値
begin

	dbms_output.put_line('テーブル: ' || tableName);
	
	-- 増幅対象コラム
	extendCols := colArrays(pk);
	-- 元データ対象コラム取得	
	colNames := getTblCols(tableName, extendCols, colArrays(' '));
	
	-- 主キー最大値取得
	sql_str := 'SELECT MAX(' || extendCols(1) || ') FROM ' || tableName;	
	execute immediate sql_str into maxID;
	dbms_output.put_line('増幅前主キー最大値 : ' || maxID);
	dbms_output.put_line('指定開始値 : ' || startValue);
	if (maxID < startValue) then
		maxID := startValue;
		dbms_output.put_line('主キーの増幅開始値 : ' || maxID);
	end if;
	
	-- 増幅対象件数
	sql_str := 'SELECT COUNT(*) FROM ' || tableName;	
	execute immediate sql_str into currentCnt;
	dbms_output.put_line('増幅対象件数 : ' || currentCnt);
	
	-- 増幅実施
	sql_str := 'INSERT /*APPEND*/ INTO ' || tableName || '('
					|| getColsWithComma(extendCols)	 --INSERT対象コラム（順番指定のため、増幅項目）
					|| ', '
					|| colNames									 --INSERT対象コラム（順番指定のため、増幅元データ項目）
					|| ') '
					
					|| 'SELECT TO_CHAR(' || maxID || '+rownum), '		--増幅項目）
					|| colNames											--増幅元データ項目
					|| ' FROM (SELECT ' || colNames || ' FROM ' || tableName	--増幅元データ項目取得
					|| ' ORDER BY ' || extendCols(1) || ')';							--ソートキー指定
	
	--sql_str := sql_str || ' WHERE rownum <= 1';  --テスト用、件数絞っている
	
	--dbms_output.put_line(sql_str); --テスト用、SQL出力
	execute immediate sql_str;
	
	-- 増幅実施後総件数
	sql_str := 'SELECT COUNT(*) FROM ' || tableName;	
	execute immediate sql_str into currentCnt;
	dbms_output.put_line('増幅実施後総件数 : ' || currentCnt);
	
end doubleTables;
/



----------------------------------------------------------------------------------------------
--　②契約関連テーブルの倍増
--　個人顧客、カード契約、契約顧客関連、契約残高
----------------------------------------------------------------------------------------------
create or replace procedure doubleSkyTables(
	sky_year in varchar, 					-- 請求年（YYYY）
	sky_month in varchar,					-- 請求月（MM）
	bill_create_date in varchar			-- 最新請求書作成年月日（YYYYMMDD）（稼働月前月）
)
is
	colNames varchar(5000); 		-- 列名
	
	logTblName varchar(500);	--ログ出力用テーブル名
	
	sql_str varchar(20000); 		--SQL文
	specifySql varchar(20000); 		--絞る用SQL文
	
	extendCols colArrays;					-- 増幅対象コラム名リスト
	defaultCols colArrays;					-- 初期値対象コラム名リスト
	defaultVals varchar(5000);		-- 初期値対象初期値
	
    currentCnt number;         		-- 現状の総件数
    extendCnt number;         		-- 増幅目標件数
	-- 個人顧客（KJN_CST）の増幅キー
    max_CST_NO number;          						-- 顧客番号最大値
	
	-- カード契約（CARD_KYK）の増幅キー
    max_MEM_NO number;          						-- 会員番号最大値
    max_CARD_TEIKEI_KYK_NO number;          	-- カード提携契約番号最大値
    max_DOJI_MOSIKOMI_MEM_NO number;      -- 同時申込会員番号最大値

	-- 契約顧客関連（KYK_CST_KANREN）の増幅キー
	max_KYK_CST_KANREN_NO number;			-- 契約顧客関連番号最大値
	max_MOSIKOMI_NO number;						-- 申込番号最大値
	max_CARD_NO number;								-- カード番号最大値
	
	-- 契約残高（KYK_ZAN）の増幅キー（なし、上記に含まれる）

begin
	---------------------------------------------------------
	-- 個人顧客、カード契約、契約顧客関連で倍増対象者絞る
	---------------------------------------------------------
	dbms_output.put_line('増幅前各キーの最大値取得' );
	-- 顧客番号最大値取得
	SELECT MAX(CST_NO) INTO max_CST_NO FROM KJN_CST;	
	dbms_output.put_line('顧客番号最大値取得 : ' || max_CST_NO);
	
	-- 会員番号最大値取得
	SELECT MAX(MEM_NO) INTO max_MEM_NO FROM CARD_KYK;
	dbms_output.put_line('会員番号最大値取得 : ' || max_MEM_NO);
	-- カード提携契約番号最大値取得
	SELECT MAX(CARD_TEIKEI_KYK_NO) INTO max_CARD_TEIKEI_KYK_NO FROM CARD_KYK;
	dbms_output.put_line('カード提携契約番号最大値取得 : ' || max_CARD_TEIKEI_KYK_NO);
	-- 同時申込会員番号最大値取得
	SELECT MAX(DOJI_MOSIKOMI_MEM_NO) INTO max_DOJI_MOSIKOMI_MEM_NO FROM CARD_KYK;
	dbms_output.put_line('同時申込会員番号最大値取得 : ' || max_DOJI_MOSIKOMI_MEM_NO);
	
	-- 契約顧客関連番号最大値取得
	SELECT MAX(KYK_CST_KANREN_NO) INTO max_KYK_CST_KANREN_NO FROM KYK_CST_KANREN;
	dbms_output.put_line('契約顧客関連番号最大値取得 : ' || max_KYK_CST_KANREN_NO);
	-- 申込番号最大値取得
	SELECT MAX(MOSIKOMI_NO) INTO max_MOSIKOMI_NO FROM KYK_CST_KANREN;
	dbms_output.put_line('申込番号最大値取得 : ' || max_MOSIKOMI_NO);
	-- カード番号最大値取得
	SELECT MAX(CARD_NO) INTO max_CARD_NO FROM KYK_CST_KANREN;
	dbms_output.put_line('カード番号最大値取得 : ' || max_CARD_NO);
	
	--　個人顧客の件数は少ないため、それをキーで絞る
	specifySql := 'SELECT KJN_CST.CST_NO CST_NO, T1.KYK_CST_KANREN_NO KYK_CST_KANREN_NO, T1.MEM_NO MEM_NO '
					||	'FROM KJN_CST INNER JOIN '
					|| '(SELECT CST_NO, MAX(KYK_CST_KANREN.KYK_CST_KANREN_NO) KYK_CST_KANREN_NO, MAX(KYK_CST_KANREN.MEM_NO) MEM_NO '
					|| 'FROM KYK_CST_KANREN INNER JOIN CARD_KYK ON CARD_KYK.MEM_NO = KYK_CST_KANREN.MEM_NO '
					|| 'WHERE KYK_CST_KANREN.DELETE_SIGN=' || addQuota('0') || ' GROUP BY CST_NO) T1 '
					|| 'ON KJN_CST.CST_NO=T1.CST_NO '
					|| 'ORDER BY KJN_CST.CST_NO'; 
	
	-- 絞っている契約顧客関連の総件数
	sql_str := 'SELECT COUNT(*) FROM (' || specifySql || ')';
	execute immediate sql_str into currentCnt;
	dbms_output.put_line('絞っている契約顧客関連の総件数 : ' || currentCnt);
	
	-- 増幅実施
	---------------------------------------------------------
	-- 個人顧客-KJN_CST
	logTblName := 'テーブル名：個人顧客(KJN_CST)　';

	-- 増幅前個人顧客総件数
	SELECT COUNT(*) INTO currentCnt FROM KJN_CST;	
	dbms_output.put_line(logTblName || '増幅実施前総件数 : ' || currentCnt);
	extendCnt := currentCnt; --増幅対象件数を設定する
	
	extendCols := colArrays('CST_NO');
	defaultCols := colArrays('DELETE_SIGN',
								'INSERT_USER_ID',
								'INSERT_DATE_TIME',
								'UPDATE_USER_ID',
								'UPDATE_DATE_TIME',
								'VERSION');
	defaultVals := addQuota('0') || ', '			--DELETE_SIGN
						|| addQuota(' ')	 || ', '		--INSERT_USER_ID
						|| 'sysdate, '						--INSERT_DATE_TIME
						|| addQuota(' ')	 || ', '		--UPDATE_USER_ID
						|| 'sysdate, 1'; 				--UPDATE_DATE_TIME, VERSION
	
	colNames := getTblCols('KJN_CST', extendCols, defaultCols);
	
	sql_str := 'INSERT /*APPEND*/ INTO KJN_CST('				--個人顧客-KJN_CST
					|| getColsWithComma(extendCols)		--INSERT対象コラム（順番指定のため、増幅項目）
					|| ', '
					|| colNames										--INSERT対象コラム（順番指定のため、増幅元データ項目）
					|| ', '
					|| getColsWithComma(defaultCols)		--INSERT対象コラム（順番指定のため、デフォルト値項目）
					|| ') '
					
					|| 'SELECT TO_CHAR(' || max_CST_NO || '+rownum), '	--増幅項目-CST_NO
					|| colNames													--増幅元データ項目
					|| ', '
					|| defaultVals	 											--デフォルト値項目
					|| ' FROM (SELECT ' || colNames || ' FROM KJN_CST WHERE '					--増幅元データ項目取得
					|| ' KJN_CST.CST_NO IN (SELECT CST_NO FROM (' || specifySql || '))'		--絞ったデータから取得
					|| ' ORDER BY KJN_CST.CST_NO)';															--ソートキー指定-CST_NO
	
	--sql_str := sql_str || ' WHERE rownum <= 10';  --テスト用、件数絞っている
	
	dbms_output.put_line(sql_str); --テスト用、SQL出力
	execute immediate sql_str;
	
	-- 増幅個人顧客総件数
	SELECT COUNT(*) INTO currentCnt FROM KJN_CST;	
	dbms_output.put_line(logTblName || '増幅実施後総件数 : ' || currentCnt);
	extendCnt := currentCnt - extendCnt; --増幅件数を設定する
	dbms_output.put_line(logTblName || '増幅件数 : ' || extendCnt);
	---------------------------------------------------------
	
	---------------------------------------------------------
	-- カード契約-CARD_KYK
	logTblName := 'テーブル名：カード契約(CARD_KYK)　';

	-- 増幅前個人顧客総件数
	SELECT COUNT(*) INTO currentCnt FROM CARD_KYK;	
	dbms_output.put_line(logTblName || '増幅実施前総件数 : ' || currentCnt);
	extendCnt := currentCnt; --増幅対象件数を設定する
	
	extendCols := colArrays('MEM_NO',
								'CARD_TEIKEI_KYK_NO',
								'DOJI_MOSIKOMI_MEM_NO');
	defaultCols := colArrays('KYK_EXPIRE_YM',                                                             ---未来月ならなんでもOK
										'CARD_KIRIKAE_YM',                                                          ---空白で良い
										'CARD_NO_FAMILY_SAIHAKKO_GENERATOR_SEQ',             -- 空白で良い
										'KYK_MOSIKOMI_INTRODUCE_CARD_NO',                           ---空白で良い
										'KYK_MOSIKOMI_INTRODUCE_USER_ID',                             -- 空白で良い
										'CARD_MOSIKOMI_INTRODUCE_KMTN_TKSK_NO',               ---空白で良い
										'NENKAIHI_MENJO_KBN',                                                   -- 免除でない値とする
										'NENKAIHI_SKY_KIJUN_YEAR',                                            ---10%を請求年で増幅。90%はなんでもOK
										'NENKAIHI_SKY_KIJUN_MONTH',                                        -- 10%を請求年で増幅。90%はなんでもOK
										'LATEST_BILL_CREATE_DATE',                                            ---50%を稼働月前月とする。50%はなんでもOK
										'BILL_STOP_SIGN',                                                            -- 5%を停止とする。95%は出力対象とする
										'KASITUKE_DETAIL_STOP_SIGN',                                        ---5%を停止とする。95%は出力対象とする
										'KZFR_TETUDUKI_ASSIGNED_KBN',                                    ---当社で設定
										'KMTN_TKSK_KBN',                                                            ---当社で設定
										'KMTN_TKSK_KYK_STS_KBN',                                             ---空白で良い
										'KMTN_TKSK_USE_INFO_TOROKU_DATE',                           ---空白で良い
										'HIGHRISK_KBN',                                                               ---リスク低とする
										'HIGHRISK_TOROKU_DATE',                                               ---空白で良い
										'HIGHRISK_JIDO_HANBETU_RESULT_KBN',                          -- 空白で良い
										'TANPO_CHOSHU_KBN',                                                     -- 担保徴収無
										'TANPO_CHOSHU_NY_KBN',                                                ---担保徴収無
										'TANPO_CHOSHU_SIGN',                                                    ---担保徴収無
										'GENERATED_TANPO_NO',                                                  ---空白で良い
										'SHUNYU_INSI_DAI',                                                          ---空白で良い
										'SHUNYU_INSI_DAI_CHOSHUSAKI_KBN',                            -- 担保徴収無
										'SHUNYU_INSI_DAI_CHOSHU_METHOD_KBN',                     ---担保徴収無
										'JIMU_TESURYO',                                                                -- 0とする
										'JIMU_TESURYO_CHOSHUSAKI_KBN',                                 -- 徴収無し
										'JIMU_TESURYO_CHOSHU_METHOD_KBN',                           -- 徴収無し
										'OTHER_HIYO_GAKU',                                                        -- 0とする-
										'OTHER_UCHIWAKE_HIYO_URI_GAKU1',                             -- 0とする-
										'OTHER_UCHIWAKE_HIYO_URI_GAKU2',                             -- 0とする-
										'OTHER_UCHIWAKE_HIYO_URI_GAKU3',                             -- 0とする-
										'OTHER_UCHIWAKE_HIYO_URI_GAKU4',                             -- 0とする-
										'OTHER_UCHIWAKE_HIYO_URI_GAKU5',                             -- 0とする-
										'OTHER_UCHIWAKE_HIYO_URI_GAKU6',                             -- 0とする-
										'KYK_DAKKAI_DATE',                                                         -- 空白で良い-
										'KYK_SHUSI_DATE',                                                            -- 空白で良い-
										'KYK_SHUSI_HENSAI_STS_KBN',                                        ---空白で良い
										'KYK_SHUSI_KANSAI_CHECK_DATE',                                   -- 空白で良い-
										'KYK_DELETE_YOTEI_DATE',                                               ---空白で良い
										'KIRIKAE_MAE_CARD_TEIKEI_KYK_NO',                              ---空白で良い
										'DIVIDE_NO',                                                                     ---プロセス数によって設定
										'DELETE_SIGN',                                                                 -- 初期値-
										'DELETE_DATE',                                                                  -- 初期値-
										'INSERT_USER_ID',                                                            ---初期値
										'INSERT_DATE_TIME',                                                        -- 初期値-
										'UPDATE_USER_ID',                                                            -- 初期値-
										'UPDATE_DATE_TIME',                                                        ---初期値
										'VERSION');                                                                       ---初期値
	defaultVals := addQuota('202305') || ', '	            	                   -- KYK_EXPIRE_YM                                                             ---未来月ならなんでもOK
						|| addQuota(' ') || ', '			         		                   -- CARD_KIRIKAE_YM                                                          ---空白で良い
						|| addQuota(' ') || ', '			         		                   -- CARD_NO_FAMILY_SAIHAKKO_GENERATOR_SEQ             -- 空白で良い
						|| addQuota(' ') || ', '			         		                   -- KYK_MOSIKOMI_INTRODUCE_CARD_NO                           ---空白で良い
						|| addQuota(' ') || ', '			         		                   -- KYK_MOSIKOMI_INTRODUCE_USER_ID                             -- 空白で良い
						|| addQuota(' ') || ', '			         		                   -- CARD_MOSIKOMI_INTRODUCE_KMTN_TKSK_NO               ---空白で良い
						|| addQuota('0') || ', '			         		                   -- NENKAIHI_MENJO_KBN                                                   -- 免除でない値とする
						|| '(CASE WHEN MOD(rownum,10) = 0 THEN ' || addQuota(sky_year) || ' ELSE ' || addQuota('2018') || ' END), '
																									   -- NENKAIHI_SKY_KIJUN_YEAR                                            ---10%を請求年で増幅。90%はなんでもOK
						|| '(CASE WHEN MOD(rownum,10) = 0 THEN ' || addQuota(sky_month) || ' ELSE ' || addQuota('01') || ' END), '
																									   -- NENKAIHI_SKY_KIJUN_MONTH                                        -- 10%を請求年で増幅。90%はなんでもOK
						|| '(CASE WHEN MOD(rownum,2) = 0 THEN ' || addQuota(bill_create_date) || ' ELSE ' || addQuota('20170101') || ' END), '
																									   -- LATEST_BILL_CREATE_DATE                                            ---50%を稼働月前月とする。50%はなんでもOK
						|| addQuota('0') || ', '			         		                    -- BILL_STOP_SIGN                                                            -- 5%を停止とする。95%は出力対象とする⇒固定値
						|| addQuota('0') || ', '			         		                    -- KASITUKE_DETAIL_STOP_SIGN                                        ---5%を停止とする。95%は出力対象とする⇒固定値
						|| addQuota('0') || ', '			         		                    -- KZFR_TETUDUKI_ASSIGNED_KBN                                    ---当社で設定
						|| addQuota('0') || ', '			         		                    -- KMTN_TKSK_KBN                                                            ---当社で設定
						|| addQuota(' ') || ', '	   		         		                    -- KMTN_TKSK_KYK_STS_KBN                                             ---空白で良い
						|| addQuota('        ') || ', '		         		                    -- KMTN_TKSK_USE_INFO_TOROKU_DATE                           ---空白で良い
						|| addQuota('0') || ', '			         		                    -- HIGHRISK_KBN                                                               ---リスク低とする
						|| addQuota('        ') || ', '		         		                    -- HIGHRISK_TOROKU_DATE                                               ---空白で良い
						|| addQuota('   ') || ', '			         		                    -- HIGHRISK_JIDO_HANBETU_RESULT_KBN                          -- 空白で良い
						|| addQuota('0') || ', '			         		                    -- TANPO_CHOSHU_KBN                                                     -- 担保徴収無
						|| addQuota('0') || ', '			         		                    -- TANPO_CHOSHU_NY_KBN                                                ---担保徴収無
						|| addQuota('0') || ', '			         		                    -- TANPO_CHOSHU_SIGN                                                    ---担保徴収無
						|| addQuota('    ') || ', '			         		                    -- GENERATED_TANPO_NO                                                  ---空白で良い
						|| '0, '			         		         						            -- SHUNYU_INSI_DAI                                                          ---空白で良い
						|| addQuota('0') || ', '			         		                    -- SHUNYU_INSI_DAI_CHOSHUSAKI_KBN                            -- 担保徴収無
						|| addQuota('0') || ', '			         		                    -- SHUNYU_INSI_DAI_CHOSHU_METHOD_KBN                     ---担保徴収無
						|| '0, '									         		                    -- JIMU_TESURYO                                                                -- 0とする
						|| addQuota('0') || ', '			         		                    -- JIMU_TESURYO_CHOSHUSAKI_KBN                                 -- 徴収無し
						|| addQuota('0') || ', '			         		                    -- JIMU_TESURYO_CHOSHU_METHOD_KBN                           -- 徴収無し
						|| '0, '									         		                    -- OTHER_HIYO_GAKU                                                        -- 0とする-
						|| '0, '									         		                    -- OTHER_UCHIWAKE_HIYO_URI_GAKU1                             -- 0とする-
						|| '0, '									         		                    -- OTHER_UCHIWAKE_HIYO_URI_GAKU2                             -- 0とする-
						|| '0, '									         		                    -- OTHER_UCHIWAKE_HIYO_URI_GAKU3                             -- 0とする-
						|| '0, '									         		                    -- OTHER_UCHIWAKE_HIYO_URI_GAKU4                             -- 0とする-
						|| '0, '									         		                    -- OTHER_UCHIWAKE_HIYO_URI_GAKU5                             -- 0とする-
						|| '0, '									         		                    -- OTHER_UCHIWAKE_HIYO_URI_GAKU6                             -- 0とする-
						|| addQuota('        ') || ', '			       		                    -- KYK_DAKKAI_DATE                                                         -- 空白で良い-
						|| addQuota('        ') || ', '			       		                    -- KYK_SHUSI_DATE                                                            -- 空白で良い-
						|| addQuota('  ') || ', '			         		                    -- KYK_SHUSI_HENSAI_STS_KBN                                        ---空白で良い
						|| addQuota('        ') || ', '			       		                    -- KYK_SHUSI_KANSAI_CHECK_DATE                                   -- 空白で良い-
						|| addQuota('        ') || ', '			       		                    -- KYK_DELETE_YOTEI_DATE                                               ---空白で良い
						|| addQuota('            ') || ', '			   		                    -- KIRIKAE_MAE_CARD_TEIKEI_KYK_NO                              ---空白で良い
						|| addQuota('1') || ', '			         		                    -- DIVIDE_NO                                                                     ---プロセス数によって設定
						|| addQuota('0') || ', '			         		                    -- DELETE_SIGN                                                                 -- 初期値-
						|| addQuota('        ') || ', '		         		                    -- DELETE_DATE                                                                  -- 初期値-
						|| addQuota(' ')	 || ', '												--INSERT_USER_ID
						|| 'sysdate, '																--INSERT_DATE_TIME
						|| addQuota(' ')	 || ', '												--UPDATE_USER_ID
						|| 'sysdate, 1'; 														--UPDATE_DATE_TIME, VERSION
	
	colNames := getTblCols('CARD_KYK', extendCols, defaultCols);
	
	sql_str := 'INSERT /*APPEND*/ INTO CARD_KYK('				--カード契約-CARD_KYK
					|| getColsWithComma(extendCols)		--INSERT対象コラム（順番指定のため、増幅項目）
					|| ', '
					|| colNames										--INSERT対象コラム（順番指定のため、増幅元データ項目）
					|| ', '
					|| getColsWithComma(defaultCols)	 	--INSERT対象コラム（順番指定のため、デフォルト値項目）
					|| ') '
	
					|| 'SELECT TO_CHAR(' || max_MEM_NO || '+rownum), '							--増幅項目-MEM_NO
					|| 'TO_CHAR(' || max_CARD_TEIKEI_KYK_NO || '+rownum), '						--増幅項目-CARD_TEIKEI_KYK_NO
					|| 'TO_CHAR(' || max_DOJI_MOSIKOMI_MEM_NO || '+rownum), '					--増幅項目-DOJI_MOSIKOMI_MEM_NO
					|| colNames																			--増幅元データ項目
					|| ', '
					|| defaultVals 																		--デフォルト値項目
					|| ' FROM (SELECT ' || colNames || ' FROM CARD_KYK INNER JOIN '		--増幅元データ項目取得
					|| ' (' || specifySql || ') T2 ON CARD_KYK.MEM_NO = T2.MEM_NO '		--絞ったデータから取得
					|| ' ORDER BY T2.CST_NO)';																--ソートキー指定-CST_NOの順より増加（関連性を保つため）
	
	--sql_str := sql_str || ' WHERE rownum <= 20';  --テスト用、件数絞っている
	
	dbms_output.put_line(sql_str); --テスト用、SQL出力
	execute immediate sql_str;
	
	-- 増幅カード契約総件数
	SELECT COUNT(*) INTO currentCnt FROM CARD_KYK;	
	dbms_output.put_line(logTblName || '増幅実施後総件数 : ' || currentCnt);
	
	extendCnt := currentCnt - extendCnt; --増幅件数を設定する
	dbms_output.put_line(logTblName || '増幅件数 : ' || extendCnt);
		
	
	-- 請求年で増幅の総件数
	sql_str := 'SELECT COUNT(*) FROM CARD_KYK WHERE LATEST_BILL_CREATE_DATE = ' 
				|| addQuota(bill_create_date) || ' AND MEM_NO >' || addQuota(max_MEM_NO);
	execute immediate sql_str into currentCnt;
	dbms_output.put_line('請求年で増幅の総件数 : ' || currentCnt);
		
	
	-- 稼働月前月の総件数
	sql_str := 'SELECT COUNT(*) FROM CARD_KYK WHERE NENKAIHI_SKY_KIJUN_YEAR = ' 
				|| addQuota(sky_year) || ' AND NENKAIHI_SKY_KIJUN_MONTH = '
				|| addQuota(sky_month) || ' AND MEM_NO >' || addQuota(max_MEM_NO);
	execute immediate sql_str into currentCnt;
	dbms_output.put_line('稼働月前月の総件数 : ' || currentCnt);
	---------------------------------------------------------
	
	-- 増幅実施後総件数
	sql_str := 'SELECT COUNT(*) FROM (' || specifySql || ')';	
	execute immediate sql_str into currentCnt;
	dbms_output.put_line('増幅実施後総件数 : ' || currentCnt);
	
end doubleSkyTables;
/
 