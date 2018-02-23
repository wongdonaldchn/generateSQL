set serveroutput on

----------------------------------------------------------------------------------------------
-- プロシージャ
----------------------------------------------------------------------------------------------
--　②契約関連テーブルの倍増
--　個人顧客、カード契約、契約顧客関連、契約残高
----------------------------------------------------------------------------------------------
create or replace procedure doubleSkyTables(
	sky_year in varchar, 					-- 請求年（YYYY）
	sky_month in varchar,					-- 請求月（MM）
	bill_create_date in varchar,			-- 最新請求書作成年月日（YYYYMMDD）（稼働月前月）
	toExtendCnt in number					-- 増幅指定件数（元データの件数より大きいの場合は元データにより増幅）
)
is
	colNames varchar(5000); 		-- 列名
	
	logTblName varchar(500);	--ログ出力用テーブル名
	
	sql_str varchar(20000); 		--SQL文
	specifySql varchar(20000); 		--絞る用SQL文
	
	extendCols colArrays;					-- 増幅対象コラム名リスト
	defaultCols colArrays;					-- 初期値対象コラム名リスト
	defaultVals varchar(5000);		-- 初期値対象初期値
	
    extendTargetCnt number;         		-- 増幅目標件数
    currentCnt number;         				-- 現状の総件数
    extendCnt number;         				-- 増幅件数
	
    max_CST_NO number;          						-- 顧客番号最大値
	max_MEM_NO number;          						-- 会員番号最大値
	max_CARD_NO number;								-- カード番号最大値
	
    max_KEY1 number;          	-- 増幅用キー１
    max_KEY2 number;      		-- 増幅用キー２
    max_KEY3 number;      		-- 増幅用キー３


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
	
	-- カード番号最大値取得
	SELECT MAX(CARD_NO) INTO max_CARD_NO FROM CARD;
	dbms_output.put_line('カード番号最大値取得 : ' || max_CARD_NO);
	
	
	--　三つのキーでそれぞれ唯一で絞る
	specifySql := 'SELECT MAX(CST_NO) CST_NO, MAX(KYK_CST_KANREN_NO) KYK_CST_KANREN_NO, MEM_NO '
					||	'FROM (SELECT CST_NO, MAX(KYK_CST_KANREN_NO) KYK_CST_KANREN_NO, MAX(MEM_NO) MEM_NO '
					|| 'FROM KYK_CST_KANREN '
					|| 'WHERE KYK_CST_KANREN.DELETE_SIGN=' || addQuota('0') || ' GROUP BY CST_NO) '
					|| 'GROUP BY MEM_NO '
					|| 'ORDER BY MEM_NO';
	
	-- 絞っている契約顧客関連の総件数
	sql_str := 'SELECT COUNT(*) FROM (' || specifySql || ')';
	execute immediate sql_str into currentCnt;
	dbms_output.put_line('絞っている契約顧客関連の総件数 : ' || currentCnt);
	
	-- 増幅目標件数を設定する
	sql_str := 'SELECT COUNT(DISTINCT MEM_NO) FROM (' || specifySql || ')';
	extendTargetCnt := currentCnt;
	if (extendTargetCnt > toExtendCnt) then
		extendTargetCnt := toExtendCnt;
	end if;
	dbms_output.put_line('増幅目標件数 : ' || extendTargetCnt);
	
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
					|| ' FROM (SELECT ' || colNames || ' FROM KJN_CST '					--増幅元データ項目取得
					|| ' INNER JOIN (' || specifySql || ') S1'		--絞ったデータから取得
					|| ' ON S1.CST_NO = KJN_CST.CST_NO'
					|| ' ORDER BY S1.MEM_NO)';															--ソートキー指定-MEM_NO
	
	sql_str := sql_str || ' WHERE rownum <= ' || extendTargetCnt;  --件数指定（もしくは最大件数）
	
	--dbms_output.put_line(sql_str); --テスト用、SQL出力
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

	-- 増幅前総件数
	SELECT COUNT(*) INTO currentCnt FROM CARD_KYK;	
	dbms_output.put_line(logTblName || '増幅実施前総件数 : ' || currentCnt);
	extendCnt := currentCnt; --増幅対象件数を設定する
	
	-- カード提携契約番号最大値取得
	SELECT MAX(CARD_TEIKEI_KYK_NO) INTO max_KEY1 FROM CARD_KYK;
	dbms_output.put_line(logTblName || 'カード提携契約番号最大値取得 : ' || max_KEY1);
	-- 同時申込会員番号最大値取得
	SELECT MAX(DOJI_MOSIKOMI_MEM_NO) INTO max_KEY2 FROM CARD_KYK;
	dbms_output.put_line(logTblName || '同時申込会員番号最大値取得 : ' || max_KEY2);
	
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
					|| 'TO_CHAR(' || max_KEY1 || '+rownum), '						--増幅項目-CARD_TEIKEI_KYK_NO
					|| 'TO_CHAR(' || max_KEY2 || '+rownum), '					--増幅項目-DOJI_MOSIKOMI_MEM_NO
					|| colNames																			--増幅元データ項目
					|| ', '
					|| defaultVals 																		--デフォルト値項目
					|| ' FROM (SELECT ' || colNames || ' FROM CARD_KYK WHERE '		--増幅元データ項目取得
					|| ' CARD_KYK.MEM_NO IN (SELECT MEM_NO FROM (' || specifySql || '))'		--絞ったデータから取得：DISTINCT済みのため、再絞る不要
					|| ' ORDER BY CARD_KYK.MEM_NO)';															--ソートキー指定-MEM_NO
	
	sql_str := sql_str || ' WHERE rownum <= ' || extendTargetCnt;  --件数指定（もしくは最大件数）
	
	--dbms_output.put_line(sql_str); --テスト用、SQL出力
	execute immediate sql_str;
	
	-- 増幅後総件数
	SELECT COUNT(*) INTO currentCnt FROM CARD_KYK;	
	dbms_output.put_line(logTblName || '増幅実施後総件数 : ' || currentCnt);
	
	extendCnt := currentCnt - extendCnt; --増幅件数を設定する
	dbms_output.put_line(logTblName || '増幅件数 : ' || extendCnt);
		
	
	-- 稼働月前月の総件数
	sql_str := 'SELECT COUNT(*) FROM CARD_KYK WHERE LATEST_BILL_CREATE_DATE = ' 
				|| addQuota(bill_create_date) || ' AND MEM_NO >' || addQuota(max_MEM_NO);
	execute immediate sql_str into currentCnt;
	dbms_output.put_line(logTblName || '稼働月前月で増幅の総件数 : ' || currentCnt);
		
	
	-- 請求年で増幅の総件数
	sql_str := 'SELECT COUNT(*) FROM CARD_KYK WHERE NENKAIHI_SKY_KIJUN_YEAR = ' 
				|| addQuota(sky_year) || ' AND NENKAIHI_SKY_KIJUN_MONTH = '
				|| addQuota(sky_month) || ' AND MEM_NO >' || addQuota(max_MEM_NO);
	execute immediate sql_str into currentCnt;
	dbms_output.put_line(logTblName || '請求年で増幅の総件数 : ' || currentCnt);
	---------------------------------------------------------
	
	
	---------------------------------------------------------
	-- カード契約利率区分-CARD_KYK_RIRITU_KBN
	logTblName := 'テーブル名：カード契約利率区分(CARD_KYK_RIRITU_KBN)　';

	-- 増幅前個人顧客総件数
	SELECT COUNT(*) INTO currentCnt FROM CARD_KYK_RIRITU_KBN;	
	dbms_output.put_line(logTblName || '増幅実施前総件数 : ' || currentCnt);
	extendCnt := currentCnt; --増幅対象件数を設定する
	
	extendCols := colArrays('MEM_NO');
	defaultCols := colArrays('SP_CS_SIKIBETU_KBN',                                                             ---ショッピングキャッシング識別区分：「1:ショッピング」固定
										'APPLY_END_URI_SIME_DATE',                                                    ---適用終了売上締年月日：空白で良い
										'RIRITU',          																			 -- 利率：DECIMAL空白で良い
										'DELETE_SIGN',                                                                 -- 初期値-
										'DELETE_DATE',                                                                  -- 初期値-
										'INSERT_USER_ID',                                                            ---初期値
										'INSERT_DATE_TIME',                                                        -- 初期値-
										'UPDATE_USER_ID',                                                            -- 初期値-
										'UPDATE_DATE_TIME');                                                      ---初期値
	defaultVals := addQuota('1') || ', '	            					                   -- SP_CS_SIKIBETU_KBN        ---ショッピングキャッシング識別区分：「1:ショッピング」固定
						|| addQuota('        ') || ', '			         		                   -- APPLY_END_URI_SIME_DATE   -適用終了売上締年月日：空白で良い
						|| '0, '			         		                   								-- RIRITU             利率：DECIMAL空白で良い
						|| addQuota('0') || ', '			         		                    -- DELETE_SIGN                                                                 -- 初期値-
						|| addQuota('        ') || ', '		         		                    -- DELETE_DATE                                                                  -- 初期値-
						|| addQuota(' ')	 || ', '												--INSERT_USER_ID
						|| 'sysdate, '																--INSERT_DATE_TIME
						|| addQuota(' ')	 || ', '												--UPDATE_USER_ID
						|| 'sysdate'; 																--UPDATE_DATE_TIME
	
	colNames := getTblCols('CARD_KYK_RIRITU_KBN', extendCols, defaultCols);
	
	sql_str := 'INSERT /*APPEND*/ INTO CARD_KYK_RIRITU_KBN('				--カード契約利率区分-CARD_KYK_RIRITU_KBN
					|| getColsWithComma(extendCols)		--INSERT対象コラム（順番指定のため、増幅項目）
					|| ', '
					|| colNames										--INSERT対象コラム（順番指定のため、増幅元データ項目）
					|| ', '
					|| getColsWithComma(defaultCols)	 	--INSERT対象コラム（順番指定のため、デフォルト値項目）
					|| ') '
	
					|| 'SELECT TO_CHAR(' || max_MEM_NO || '+rownum), '							--増幅項目-MEM_NO
					|| colNames																			--増幅元データ項目
					|| ', '
					|| defaultVals 																		--デフォルト値項目
					|| ' FROM (SELECT ' || colNames || ' FROM CARD_KYK_RIRITU_KBN M1 INNER JOIN '		--増幅元データ項目取得
					|| '(SELECT MEM_NO PK1, '																			--複数主キーを絞る
					|| 'MAX(SP_CS_SIKIBETU_KBN) PK2, '															--複数主キーを絞る
					|| 'MAX(APPLY_START_URI_SIME_DATE) PK3 '												--複数主キーを絞る
					|| 'FROM CARD_KYK_RIRITU_KBN '
					|| 'WHERE CARD_KYK_RIRITU_KBN.MEM_NO IN (SELECT MEM_NO FROM (' || specifySql || ')) '		--絞ったデータから取得
					|| 'GROUP BY MEM_NO) S1 '	
					|| 'ON M1.MEM_NO = S1.PK1 '																		--複数主キーを絞る
					|| 'AND M1.SP_CS_SIKIBETU_KBN = S1.PK2 '													--複数主キーを絞る
					|| 'AND M1.APPLY_START_URI_SIME_DATE = S1.PK3 '									--複数主キーを絞る
					|| 'ORDER BY M1.MEM_NO)';																			--ソートキー指定-MEM_NO
	
	sql_str := sql_str || ' WHERE rownum <= ' || extendTargetCnt;  --件数指定（もしくは最大件数）
	
	--dbms_output.put_line(sql_str); --テスト用、SQL出力
	execute immediate sql_str;
	
	-- 増幅後総件数
	SELECT COUNT(*) INTO currentCnt FROM CARD_KYK_RIRITU_KBN;	
	dbms_output.put_line(logTblName || '増幅実施後総件数 : ' || currentCnt);
	
	extendCnt := currentCnt - extendCnt; --増幅件数を設定する
	dbms_output.put_line(logTblName || '増幅件数 : ' || extendCnt);

	---------------------------------------------------------
	
	---------------------------------------------------------
	-- カード契約支払コース-CARD_KYK_SHR_COURSE
	logTblName := 'テーブル名：カード契約支払コース(CARD_KYK_SHR_COURSE)　';

	-- 増幅前個人顧客総件数
	SELECT COUNT(*) INTO currentCnt FROM CARD_KYK_SHR_COURSE;	
	dbms_output.put_line(logTblName || '増幅実施前総件数 : ' || currentCnt);
	extendCnt := currentCnt; --増幅対象件数を設定する
	
	extendCols := colArrays('MEM_NO');
	defaultCols := colArrays('APPLY_END_SKY_SIME_DATE',                                                    ---適用終了請求締年月日：空白で良い
										'DELETE_SIGN',                                                                 -- 初期値-
										'DELETE_DATE',                                                                  -- 初期値-
										'INSERT_USER_ID',                                                            ---初期値
										'INSERT_DATE_TIME',                                                        -- 初期値-
										'UPDATE_USER_ID',                                                            -- 初期値-
										'UPDATE_DATE_TIME');                                                      ---初期値
	defaultVals := addQuota('        ') || ', '			         		                   -- APPLY_END_SKY_SIME_DATE   -適用終了請求締年月日：空白で良い
						|| addQuota('0') || ', '			         		                    -- DELETE_SIGN                                                                 -- 初期値-
						|| addQuota('        ') || ', '		         		                    -- DELETE_DATE                                                                  -- 初期値-
						|| addQuota(' ')	 || ', '												--INSERT_USER_ID
						|| 'sysdate, '																--INSERT_DATE_TIME
						|| addQuota(' ')	 || ', '												--UPDATE_USER_ID
						|| 'sysdate'; 																--UPDATE_DATE_TIME
	
	colNames := getTblCols('CARD_KYK_SHR_COURSE', extendCols, defaultCols);
	
	sql_str := 'INSERT /*APPEND*/ INTO CARD_KYK_SHR_COURSE('				--カード契約利率区分-CARD_KYK_SHR_COURSE
					|| getColsWithComma(extendCols)		--INSERT対象コラム（順番指定のため、増幅項目）
					|| ', '
					|| colNames										--INSERT対象コラム（順番指定のため、増幅元データ項目）
					|| ', '
					|| getColsWithComma(defaultCols)	 	--INSERT対象コラム（順番指定のため、デフォルト値項目）
					|| ') '
	
					|| 'SELECT TO_CHAR(' || max_MEM_NO || '+rownum), '							--増幅項目-MEM_NO
					|| colNames																			--増幅元データ項目
					|| ', '
					|| defaultVals 																		--デフォルト値項目
					|| ' FROM (SELECT ' || colNames || ' FROM CARD_KYK_SHR_COURSE M1 INNER JOIN '		--増幅元データ項目取得
					|| '(SELECT MEM_NO PK1, '													--複数主キーを絞る
					|| 'MAX(APPLY_START_SKY_SIME_DATE) PK2 '						--複数主キーを絞る
					|| 'FROM CARD_KYK_SHR_COURSE '
					|| 'WHERE CARD_KYK_SHR_COURSE.MEM_NO IN (SELECT MEM_NO FROM (' || specifySql || ')) '		--絞ったデータから取得
					|| 'GROUP BY MEM_NO) S1 '	
					|| 'ON M1.MEM_NO = S1.PK1 '												--複数主キーを絞る
					|| 'AND M1.APPLY_START_SKY_SIME_DATE = S1.PK2 '			--複数主キーを絞る
					|| 'ORDER BY M1.MEM_NO)';													--ソートキー指定-MEM_NO
	
	sql_str := sql_str || ' WHERE rownum <= ' || extendTargetCnt;  --件数指定（もしくは最大件数）
	
	--dbms_output.put_line(sql_str); --テスト用、SQL出力
	execute immediate sql_str;
	
	-- 増幅後総件数
	SELECT COUNT(*) INTO currentCnt FROM CARD_KYK_SHR_COURSE;	
	dbms_output.put_line(logTblName || '増幅実施後総件数 : ' || currentCnt);
	
	extendCnt := currentCnt - extendCnt; --増幅件数を設定する
	dbms_output.put_line(logTblName || '増幅件数 : ' || extendCnt);

	---------------------------------------------------------
	
	
	---------------------------------------------------------
	-- カード会員WEB登録情報履歴-CARD_MEM_WEB_TOROKU_INFO_HISTORY
	logTblName := 'テーブル名：カード会員WEB登録情報履歴(CARD_MEM_WEB_TOROKU_INFO_HISTORY)　';

	-- 増幅前個人顧客総件数
	SELECT COUNT(*) INTO currentCnt FROM CARD_MEM_WEB_TOROKU_INFO_HISTORY;	
	dbms_output.put_line(logTblName || '増幅実施前総件数 : ' || currentCnt);
	extendCnt := currentCnt; --増幅対象件数を設定する
	
	extendCols := colArrays('MEM_NO');
	defaultCols := colArrays('WEB_GYOMU_SEQ',                                                    ---WEB業務連番：会員番号、WEB業務区分毎に00001からの連番。
										'DELETE_SIGN',                                                                 -- 初期値-
										'DELETE_DATE',                                                                  -- 初期値-
										'INSERT_USER_ID',                                                            ---初期値
										'INSERT_DATE_TIME',                                                        -- 初期値-
										'UPDATE_USER_ID',                                                            -- 初期値-
										'UPDATE_DATE_TIME');                                                      ---初期値
	defaultVals := '1, '			         		                   								-- WEB_GYOMU_SEQ   WEB業務連番：会員番号、WEB業務区分毎に00001からの連番。
						|| addQuota('0') || ', '			         		                    -- DELETE_SIGN                                                                 -- 初期値-
						|| addQuota('        ') || ', '		         		                    -- DELETE_DATE                                                                  -- 初期値-
						|| addQuota(' ')	 || ', '												--INSERT_USER_ID
						|| 'sysdate, '																--INSERT_DATE_TIME
						|| addQuota(' ')	 || ', '												--UPDATE_USER_ID
						|| 'sysdate'; 																--UPDATE_DATE_TIME
	
	colNames := getTblCols('CARD_MEM_WEB_TOROKU_INFO_HISTORY', extendCols, defaultCols);
	
	sql_str := 'INSERT /*APPEND*/ INTO CARD_MEM_WEB_TOROKU_INFO_HISTORY('				--カード会員WEB登録情報履歴-CARD_MEM_WEB_TOROKU_INFO_HISTORY
					|| getColsWithComma(extendCols)		--INSERT対象コラム（順番指定のため、増幅項目）
					|| ', '
					|| colNames										--INSERT対象コラム（順番指定のため、増幅元データ項目）
					|| ', '
					|| getColsWithComma(defaultCols)	 	--INSERT対象コラム（順番指定のため、デフォルト値項目）
					|| ') '
	
					|| 'SELECT TO_CHAR(' || max_MEM_NO || '+rownum), '							--増幅項目-MEM_NO
					|| colNames																			--増幅元データ項目
					|| ', '
					|| defaultVals 																		--デフォルト値項目
					|| ' FROM (SELECT ' || colNames || ' FROM CARD_MEM_WEB_TOROKU_INFO_HISTORY M1 INNER JOIN '		--増幅元データ項目取得
					|| '(SELECT MEM_NO PK1, '													--複数主キーを絞る
					|| 'MAX(WEB_GYOMU_KBN) PK2, '						--複数主キーを絞る
					|| 'MAX(WEB_GYOMU_SEQ) PK3 '						--複数主キーを絞る
					|| 'FROM CARD_MEM_WEB_TOROKU_INFO_HISTORY '
					|| 'WHERE CARD_MEM_WEB_TOROKU_INFO_HISTORY.MEM_NO IN (SELECT MEM_NO FROM (' || specifySql || ')) '		--絞ったデータから取得
					|| 'GROUP BY MEM_NO) S1 '	
					|| 'ON M1.MEM_NO = S1.PK1 '												--複数主キーを絞る
					|| 'AND M1.WEB_GYOMU_KBN = S1.PK2 '			--複数主キーを絞る
					|| 'AND M1.WEB_GYOMU_SEQ = S1.PK3 '			--複数主キーを絞る
					|| 'ORDER BY M1.MEM_NO)';													--ソートキー指定-MEM_NO
	
	sql_str := sql_str || ' WHERE rownum <= ' || extendTargetCnt;  --件数指定（もしくは最大件数）
	
	--dbms_output.put_line(sql_str); --テスト用、SQL出力
	execute immediate sql_str;
	
	-- 増幅後総件数
	SELECT COUNT(*) INTO currentCnt FROM CARD_MEM_WEB_TOROKU_INFO_HISTORY;	
	dbms_output.put_line(logTblName || '増幅実施後総件数 : ' || currentCnt);
	
	extendCnt := currentCnt - extendCnt; --増幅件数を設定する
	dbms_output.put_line(logTblName || '増幅件数 : ' || extendCnt);

	---------------------------------------------------------
	
	
	---------------------------------------------------------
	-- カード-CARD
	logTblName := 'テーブル名：カード(CARD)　';

	-- 増幅前総件数
	SELECT COUNT(*) INTO currentCnt FROM CARD;	
	dbms_output.put_line(logTblName || '増幅実施前総件数 : ' || currentCnt);
	extendCnt := currentCnt; --増幅対象件数を設定する
	
	extendCols := colArrays('CARD_NO',
										'MEM_NO');
	defaultCols := colArrays('DELETE_SIGN',                                                                 -- 初期値-
										'DELETE_DATE',                                                                  -- 初期値-
										'INSERT_USER_ID',                                                            ---初期値
										'INSERT_DATE_TIME',                                                        -- 初期値-
										'UPDATE_USER_ID',                                                            -- 初期値-
										'UPDATE_DATE_TIME');                                                      ---初期値
	defaultVals := addQuota('0') || ', '			         		                    -- DELETE_SIGN                                                                 -- 初期値-
						|| addQuota('        ') || ', '		         		                    -- DELETE_DATE                                                                  -- 初期値-
						|| addQuota(' ')	 || ', '												--INSERT_USER_ID
						|| 'sysdate, '																--INSERT_DATE_TIME
						|| addQuota(' ')	 || ', '												--UPDATE_USER_ID
						|| 'sysdate'; 																--UPDATE_DATE_TIME
	
	colNames := getTblCols('CARD', extendCols, defaultCols);
	
	sql_str := 'INSERT /*APPEND*/ INTO CARD('				--カード-CARD
					|| getColsWithComma(extendCols)		--INSERT対象コラム（順番指定のため、増幅項目）
					|| ', '
					|| colNames										--INSERT対象コラム（順番指定のため、増幅元データ項目）
					|| ', '
					|| getColsWithComma(defaultCols)	 	--INSERT対象コラム（順番指定のため、デフォルト値項目）
					|| ') '
	
					|| 'SELECT TO_CHAR(' || max_CARD_NO || '+rownum), '			--増幅項目-CARD_NO
					|| 'TO_CHAR(' || max_MEM_NO || '+rownum), '							--増幅項目-MEM_NO
					|| colNames																			--増幅元データ項目
					|| ', '
					|| defaultVals 																		--デフォルト値項目
					|| ' FROM (SELECT ' || colNames || ' FROM CARD M1 INNER JOIN '		--増幅元データ項目取得
					|| '(SELECT MEM_NO PK1, '													--複数主キーを絞る
					|| 'MAX(CARD_NO) PK2 '						--複数主キーを絞る
					|| 'FROM CARD '
					|| 'WHERE CARD.MEM_NO IN (SELECT MEM_NO FROM (' || specifySql || ')) '		--絞ったデータから取得
					|| 'GROUP BY MEM_NO) S1 '	
					|| 'ON M1.MEM_NO = S1.PK1 '												--複数主キーを絞る
					|| 'AND M1.CARD_NO = S1.PK2 '			--複数主キーを絞る
					|| 'ORDER BY M1.MEM_NO)';													--ソートキー指定-MEM_NO
	
	sql_str := sql_str || ' WHERE rownum <= ' || extendTargetCnt;  --件数指定（もしくは最大件数）
	
	--dbms_output.put_line(sql_str); --テスト用、SQL出力
	execute immediate sql_str;
	
	-- 増幅後総件数
	SELECT COUNT(*) INTO currentCnt FROM CARD;	
	dbms_output.put_line(logTblName || '増幅実施後総件数 : ' || currentCnt);
	
	extendCnt := currentCnt - extendCnt; --増幅件数を設定する
	dbms_output.put_line(logTblName || '増幅件数 : ' || extendCnt);

	---------------------------------------------------------
	
	---------------------------------------------------------
	-- 付帯カード-FUTAI_CARD
	logTblName := 'テーブル名：付帯カード(FUTAI_CARD)　';

	-- 増幅前総件数
	SELECT COUNT(*) INTO currentCnt FROM FUTAI_CARD;	
	dbms_output.put_line(logTblName || '増幅実施前総件数 : ' || currentCnt);
	extendCnt := currentCnt; --増幅対象件数を設定する
	
	-- 付帯カード管理番号最大値取得
	SELECT MAX(FUTAI_CARD_KANRI_NO) INTO max_KEY1 FROM FUTAI_CARD;
	dbms_output.put_line(logTblName || '付帯カード管理番号最大値取得 : ' || max_KEY1);
	
	extendCols := colArrays('FUTAI_CARD_KANRI_NO',
										'MEM_NO',
										'CARD_NO');
	defaultCols := colArrays('DELETE_SIGN',                                                                 -- 初期値-
										'DELETE_DATE',                                                                  -- 初期値-
										'INSERT_USER_ID',                                                            ---初期値
										'INSERT_DATE_TIME',                                                        -- 初期値-
										'UPDATE_USER_ID',                                                            -- 初期値-
										'UPDATE_DATE_TIME');                                                      ---初期値
	defaultVals := addQuota('0') || ', '			         		                    -- DELETE_SIGN                                                                 -- 初期値-
						|| addQuota('        ') || ', '		         		                    -- DELETE_DATE                                                                  -- 初期値-
						|| addQuota(' ')	 || ', '												--INSERT_USER_ID
						|| 'sysdate, '																--INSERT_DATE_TIME
						|| addQuota(' ')	 || ', '												--UPDATE_USER_ID
						|| 'sysdate'; 																--UPDATE_DATE_TIME
	
	colNames := getTblCols('FUTAI_CARD', extendCols, defaultCols);
	
	sql_str := 'INSERT /*APPEND*/ INTO FUTAI_CARD('				--付帯カード-FUTAI_CARD
					|| getColsWithComma(extendCols)		--INSERT対象コラム（順番指定のため、増幅項目）
					|| ', '
					|| colNames										--INSERT対象コラム（順番指定のため、増幅元データ項目）
					|| ', '
					|| getColsWithComma(defaultCols)	 	--INSERT対象コラム（順番指定のため、デフォルト値項目）
					|| ') '
	
					|| 'SELECT TO_CHAR(' || max_KEY1 || '+rownum), '			--増幅項目-FUTAI_CARD_KANRI_NO
					|| 'TO_CHAR(' || max_MEM_NO || '+rownum), '							--増幅項目-MEM_NO
					|| 'TO_CHAR(' || max_CARD_NO || '+rownum), '							--増幅項目-CARD_NO
					|| colNames																			--増幅元データ項目
					|| ', '
					|| defaultVals 																		--デフォルト値項目
					|| ' FROM (SELECT ' || colNames || ' FROM FUTAI_CARD M1 INNER JOIN '		--増幅元データ項目取得
					|| '(SELECT MEM_NO PK1, '													--複数主キーを絞る
					|| 'MAX(FUTAI_CARD_KANRI_NO) PK2, '						--複数主キーを絞る
					|| 'MAX(CARD_NO) PK3 '						--複数主キーを絞る
					|| 'FROM FUTAI_CARD '
					|| 'WHERE FUTAI_CARD.MEM_NO IN (SELECT MEM_NO FROM (' || specifySql || ')) '		--絞ったデータから取得
					|| 'GROUP BY MEM_NO) S1 '	
					|| 'ON M1.MEM_NO = S1.PK1 '												--複数主キーを絞る
					|| 'AND M1.FUTAI_CARD_KANRI_NO = S1.PK2 '			--複数主キーを絞る
					|| 'AND M1.CARD_NO = S1.PK3 '			--複数主キーを絞る
					|| 'ORDER BY M1.MEM_NO)';													--ソートキー指定-MEM_NO
	
	sql_str := sql_str || ' WHERE rownum <= ' || extendTargetCnt;  --件数指定（もしくは最大件数）
	
	--dbms_output.put_line(sql_str); --テスト用、SQL出力
	execute immediate sql_str;
	
	-- 増幅後総件数
	SELECT COUNT(*) INTO currentCnt FROM FUTAI_CARD;	
	dbms_output.put_line(logTblName || '増幅実施後総件数 : ' || currentCnt);
	
	extendCnt := currentCnt - extendCnt; --増幅件数を設定する
	dbms_output.put_line(logTblName || '増幅件数 : ' || extendCnt);

	---------------------------------------------------------
	
	---------------------------------------------------------
	-- 承認売上残高-AUTH_URI_ZAN
	logTblName := 'テーブル名：承認売上残高(AUTH_URI_ZAN)　';

	-- 増幅前総件数
	SELECT COUNT(*) INTO currentCnt FROM AUTH_URI_ZAN;	
	dbms_output.put_line(logTblName || '増幅実施前総件数 : ' || currentCnt);
	extendCnt := currentCnt; --増幅対象件数を設定する
	
	extendCols := colArrays('MEM_NO');
	defaultCols := colArrays('DELETE_SIGN',                                                                 -- 初期値-
										'DELETE_DATE',                                                                  -- 初期値-
										'INSERT_USER_ID',                                                            ---初期値
										'INSERT_DATE_TIME',                                                        -- 初期値-
										'UPDATE_USER_ID',                                                            -- 初期値-
										'UPDATE_DATE_TIME',                                                            -- 初期値-
										'VERSION');                                                      ---初期値
	defaultVals := addQuota('0') || ', '			         		                    -- DELETE_SIGN                                                                 -- 初期値-
						|| addQuota('        ') || ', '		         		                    -- DELETE_DATE                                                                  -- 初期値-
						|| addQuota(' ')	 || ', '												--INSERT_USER_ID
						|| 'sysdate, '																--INSERT_DATE_TIME
						|| addQuota(' ')	 || ', '												--UPDATE_USER_ID
						|| 'sysdate, 1'; 																--UPDATE_DATE_TIME,VERSION
	
	colNames := getTblCols('AUTH_URI_ZAN', extendCols, defaultCols);
	
	sql_str := 'INSERT /*APPEND*/ INTO AUTH_URI_ZAN('				--承認売上残高-AUTH_URI_ZAN
					|| getColsWithComma(extendCols)		--INSERT対象コラム（順番指定のため、増幅項目）
					|| ', '
					|| colNames										--INSERT対象コラム（順番指定のため、増幅元データ項目）
					|| ', '
					|| getColsWithComma(defaultCols)	 	--INSERT対象コラム（順番指定のため、デフォルト値項目）
					|| ') '
	
					|| 'SELECT TO_CHAR(' || max_MEM_NO || '+rownum), '							--増幅項目-MEM_NO
					|| colNames																			--増幅元データ項目
					|| ', '
					|| defaultVals 																		--デフォルト値項目
					|| ' FROM (SELECT ' || colNames || ' FROM AUTH_URI_ZAN WHERE '		--増幅元データ項目取得
					|| ' AUTH_URI_ZAN.MEM_NO IN (SELECT MEM_NO FROM (' || specifySql || '))'		--絞ったデータから取得：DISTINCT済みのため、再絞る不要
					|| ' ORDER BY AUTH_URI_ZAN.MEM_NO)';															--ソートキー指定-MEM_NO
	
	sql_str := sql_str || ' WHERE rownum <= ' || extendTargetCnt;  --件数指定（もしくは最大件数）
	
	--dbms_output.put_line(sql_str); --テスト用、SQL出力
	execute immediate sql_str;
	
	-- 増幅後総件数
	SELECT COUNT(*) INTO currentCnt FROM AUTH_URI_ZAN;	
	dbms_output.put_line(logTblName || '増幅実施後総件数 : ' || currentCnt);
	
	extendCnt := currentCnt - extendCnt; --増幅件数を設定する
	dbms_output.put_line(logTblName || '増幅件数 : ' || extendCnt);

	---------------------------------------------------------
	
	---------------------------------------------------------
	-- 契約残高-KYK_ZAN
	logTblName := 'テーブル名：契約残高(KYK_ZAN)　';

	-- 増幅前総件数
	SELECT COUNT(*) INTO currentCnt FROM KYK_ZAN;	
	dbms_output.put_line(logTblName || '増幅実施前総件数 : ' || currentCnt);
	extendCnt := currentCnt; --増幅対象件数を設定する
	
	extendCols := colArrays('MEM_NO',
										'CST_NO');
	defaultCols := colArrays('DELETE_SIGN',                                                                 -- 初期値-
										'DELETE_DATE',                                                                  -- 初期値-
										'INSERT_USER_ID',                                                            ---初期値
										'INSERT_DATE_TIME',                                                        -- 初期値-
										'UPDATE_USER_ID',                                                            -- 初期値-
										'UPDATE_DATE_TIME',                                                            -- 初期値-
										'VERSION');                                                      ---初期値
	defaultVals := addQuota('0') || ', '			         		                    -- DELETE_SIGN                                                                 -- 初期値-
						|| addQuota('        ') || ', '		         		                    -- DELETE_DATE                                                                  -- 初期値-
						|| addQuota(' ')	 || ', '												--INSERT_USER_ID
						|| 'sysdate, '																--INSERT_DATE_TIME
						|| addQuota(' ')	 || ', '												--UPDATE_USER_ID
						|| 'sysdate, 1'; 																--UPDATE_DATE_TIME,VERSION
	
	colNames := getTblCols('KYK_ZAN', extendCols, defaultCols);
	
	sql_str := 'INSERT /*APPEND*/ INTO KYK_ZAN('				--契約残高-KYK_ZAN
					|| getColsWithComma(extendCols)		--INSERT対象コラム（順番指定のため、増幅項目）
					|| ', '
					|| colNames										--INSERT対象コラム（順番指定のため、増幅元データ項目）
					|| ', '
					|| getColsWithComma(defaultCols)	 	--INSERT対象コラム（順番指定のため、デフォルト値項目）
					|| ') '
	
					|| 'SELECT TO_CHAR(' || max_MEM_NO || '+rownum), '							--増幅項目-MEM_NO
					|| 'TO_CHAR(' || max_CST_NO || '+rownum), '							--増幅項目-CST_NO
					|| colNames																			--増幅元データ項目
					|| ', '
					|| defaultVals 																		--デフォルト値項目
					|| ' FROM (SELECT ' || colNames || ' FROM KYK_ZAN WHERE '		--増幅元データ項目取得
					|| ' KYK_ZAN.MEM_NO IN (SELECT MEM_NO FROM (' || specifySql || '))'		--絞ったデータから取得：DISTINCT済みのため、再絞る不要
					|| ' ORDER BY KYK_ZAN.MEM_NO)';															--ソートキー指定-MEM_NO
	
	sql_str := sql_str || ' WHERE rownum <= ' || extendTargetCnt;  --件数指定（もしくは最大件数）
	
	--dbms_output.put_line(sql_str); --テスト用、SQL出力
	execute immediate sql_str;
	
	-- 増幅後総件数
	SELECT COUNT(*) INTO currentCnt FROM KYK_ZAN;	
	dbms_output.put_line(logTblName || '増幅実施後総件数 : ' || currentCnt);
	
	extendCnt := currentCnt - extendCnt; --増幅件数を設定する
	dbms_output.put_line(logTblName || '増幅件数 : ' || extendCnt);

	---------------------------------------------------------
	
	---------------------------------------------------------
	-- 口座-KZ
	logTblName := 'テーブル名：口座(KZ)　';

	-- 増幅前総件数
	SELECT COUNT(*) INTO currentCnt FROM KZ;	
	dbms_output.put_line(logTblName || '増幅実施前総件数 : ' || currentCnt);
	extendCnt := currentCnt; --増幅対象件数を設定する
	
	-- 口座管理番号最大値取得
	SELECT MAX(KZ_KANRI_NO) INTO max_KEY1 FROM KZ;
	dbms_output.put_line(logTblName || '口座管理番号最大値取得 : ' || max_KEY1);
	
	extendCols := colArrays('KZ_KANRI_NO');
	defaultCols := colArrays('DELETE_SIGN',                                                                 -- 初期値-
										'DELETE_DATE',                                                                  -- 初期値-
										'INSERT_USER_ID',                                                            ---初期値
										'INSERT_DATE_TIME',                                                        -- 初期値-
										'UPDATE_USER_ID',                                                            -- 初期値-
										'UPDATE_DATE_TIME',                                                            -- 初期値-
										'VERSION');                                                      ---初期値
	defaultVals := addQuota('0') || ', '			         		                    -- DELETE_SIGN                                                                 -- 初期値-
						|| addQuota('        ') || ', '		         		                    -- DELETE_DATE                                                                  -- 初期値-
						|| addQuota(' ')	 || ', '												--INSERT_USER_ID
						|| 'sysdate, '																--INSERT_DATE_TIME
						|| addQuota(' ')	 || ', '												--UPDATE_USER_ID
						|| 'sysdate, 1'; 																--UPDATE_DATE_TIME,VERSION
	
	colNames := getTblCols('KZ', extendCols, defaultCols);
	
	sql_str := 'INSERT /*APPEND*/ INTO KZ('				--口座-KZ
					|| getColsWithComma(extendCols)		--INSERT対象コラム（順番指定のため、増幅項目）
					|| ', '
					|| colNames										--INSERT対象コラム（順番指定のため、増幅元データ項目）
					|| ', '
					|| getColsWithComma(defaultCols)	 	--INSERT対象コラム（順番指定のため、デフォルト値項目）
					|| ') '
	
					|| 'SELECT TO_CHAR(' || max_KEY1 || '+rownum), '			--増幅項目-KZ_KANRI_NO
					|| colNames																			--増幅元データ項目
					|| ', '
					|| defaultVals 																		--デフォルト値項目
					|| ' FROM (SELECT ' || colNames || ' FROM KZ M1 INNER JOIN '		--増幅元データ項目取得
					|| '(SELECT MEM_NO PK1, '													--複数主キーを絞る
					|| 'MAX(KYK_KZ_KANRI_NO) PK2, '						--複数主キーを絞る
					|| 'MAX(KZ_KANRI_NO) PK3 '						--複数主キーを絞る
					|| 'FROM KYK_KZ '
					|| 'WHERE KYK_KZ.MEM_NO IN (SELECT MEM_NO FROM (' || specifySql || ')) '		--絞ったデータから取得
					|| 'GROUP BY MEM_NO) S1 '	
					|| 'ON M1.KZ_KANRI_NO = S1.PK3 '			--複数主キーを絞る
					|| 'ORDER BY S1.PK1)';													--ソートキー指定-MEM_NO
	
	sql_str := sql_str || ' WHERE rownum <= ' || extendTargetCnt;  --件数指定（もしくは最大件数）
	
	--dbms_output.put_line(sql_str); --テスト用、SQL出力
	execute immediate sql_str;
	
	-- 増幅後総件数
	SELECT COUNT(*) INTO currentCnt FROM KZ;	
	dbms_output.put_line(logTblName || '増幅実施後総件数 : ' || currentCnt);
	
	extendCnt := currentCnt - extendCnt; --増幅件数を設定する
	dbms_output.put_line(logTblName || '増幅件数 : ' || extendCnt);

	---------------------------------------------------------
	
	---------------------------------------------------------
	-- 契約口座-KYK_KZ （関連性あるから、口座テーブルの後で増幅）
	logTblName := 'テーブル名：契約口座(KYK_KZ)　';

	-- 増幅前総件数
	SELECT COUNT(*) INTO currentCnt FROM KYK_KZ;	
	dbms_output.put_line(logTblName || '増幅実施前総件数 : ' || currentCnt);
	extendCnt := currentCnt; --増幅対象件数を設定する
	
	-- 契約口座管理番号最大値取得
	SELECT MAX(KYK_KZ_KANRI_NO) INTO max_KEY1 FROM KYK_KZ;
	dbms_output.put_line(logTblName || '契約口座管理番号最大値取得 : ' || max_KEY1);
	-- 口座管理番号最大値取得
	SELECT MAX(KZ_KANRI_NO) INTO max_KEY2 FROM KZ;
	dbms_output.put_line(logTblName || '口座管理番号最大値取得 : ' || max_KEY2);
	
	extendCols := colArrays('KYK_KZ_KANRI_NO',
										'MEM_NO',
										'KZ_KANRI_NO');
	defaultCols := colArrays('DELETE_SIGN',                                                                 -- 初期値-
										'DELETE_DATE',                                                                  -- 初期値-
										'INSERT_USER_ID',                                                            ---初期値
										'INSERT_DATE_TIME',                                                        -- 初期値-
										'UPDATE_USER_ID',                                                            -- 初期値-
										'UPDATE_DATE_TIME');                                                      ---初期値
	defaultVals := addQuota('0') || ', '			         		                    -- DELETE_SIGN                                                                 -- 初期値-
						|| addQuota('        ') || ', '		         		                    -- DELETE_DATE                                                                  -- 初期値-
						|| addQuota(' ')	 || ', '												--INSERT_USER_ID
						|| 'sysdate, '																--INSERT_DATE_TIME
						|| addQuota(' ')	 || ', '												--UPDATE_USER_ID
						|| 'sysdate'; 																--UPDATE_DATE_TIME
	
	colNames := getTblCols('KYK_KZ', extendCols, defaultCols);
	
	sql_str := 'INSERT /*APPEND*/ INTO KYK_KZ('				--契約口座-KYK_KZ
					|| getColsWithComma(extendCols)		--INSERT対象コラム（順番指定のため、増幅項目）
					|| ', '
					|| colNames										--INSERT対象コラム（順番指定のため、増幅元データ項目）
					|| ', '
					|| getColsWithComma(defaultCols)	 	--INSERT対象コラム（順番指定のため、デフォルト値項目）
					|| ') '
	
					|| 'SELECT TO_CHAR(' || max_KEY1 || '+rownum), '			--増幅項目-KYK_KZ_KANRI_NO
					|| 'TO_CHAR(' || max_MEM_NO || '+rownum), '							--増幅項目-MEM_NO
					|| 'TO_CHAR(' || max_KEY2 || '+rownum), '							--増幅項目-KZ_KANRI_NO
					|| colNames																			--増幅元データ項目
					|| ', '
					|| defaultVals 																		--デフォルト値項目
					|| ' FROM (SELECT ' || colNames || ' FROM KYK_KZ M1 INNER JOIN '		--増幅元データ項目取得
					|| '(SELECT MEM_NO PK1, '													--複数主キーを絞る
					|| 'MAX(KYK_KZ_KANRI_NO) PK2 '						--複数主キーを絞る
					|| 'FROM KYK_KZ '
					|| 'WHERE KYK_KZ.MEM_NO IN (SELECT MEM_NO FROM (' || specifySql || ')) '		--絞ったデータから取得
					|| 'GROUP BY MEM_NO) S1 '	
					|| 'ON M1.MEM_NO = S1.PK1 '												--複数主キーを絞る
					|| 'AND M1.KYK_KZ_KANRI_NO = S1.PK2 '			--複数主キーを絞る
					|| 'ORDER BY M1.MEM_NO)';													--ソートキー指定-MEM_NO
	
	sql_str := sql_str || ' WHERE rownum <= ' || extendTargetCnt;  --件数指定（もしくは最大件数）
	
	--dbms_output.put_line(sql_str); --テスト用、SQL出力
	execute immediate sql_str;
	
	-- 増幅後総件数
	SELECT COUNT(*) INTO currentCnt FROM KYK_KZ;	
	dbms_output.put_line(logTblName || '増幅実施後総件数 : ' || currentCnt);
	
	extendCnt := currentCnt - extendCnt; --増幅件数を設定する
	dbms_output.put_line(logTblName || '増幅件数 : ' || extendCnt);

	---------------------------------------------------------
	
	
	---------------------------------------------------------
	-- 契約顧客関連-KYK_CST_KANREN （関連性あるから、最後で増幅）
	logTblName := 'テーブル名：契約顧客関連(KYK_CST_KANREN)　';

	-- 増幅前総件数
	SELECT COUNT(*) INTO currentCnt FROM KYK_CST_KANREN;	
	dbms_output.put_line(logTblName || '増幅実施前総件数 : ' || currentCnt);
	extendCnt := currentCnt; --増幅対象件数を設定する
	
	-- 契約顧客関連番号最大値取得
	SELECT MAX(KYK_CST_KANREN_NO) INTO max_KEY1 FROM KYK_CST_KANREN;
	dbms_output.put_line(logTblName || '契約顧客関連番号最大値取得 : ' || max_KEY1);
	-- 申込番号最大値取得
	SELECT MAX(MOSIKOMI_NO) INTO max_KEY2 FROM KYK_CST_KANREN;
	dbms_output.put_line(logTblName || '申込番号最大値取得 : ' || max_KEY2);
	
	extendCols := colArrays('KYK_CST_KANREN_NO',
										'MEM_NO',
										'CST_NO',
										'MOSIKOMI_NO',
										'CARD_NO');
	defaultCols := colArrays('CARD_HAKKO_SIGN',                                                        -- カード発行有サイン：有：1
										'DELETE_SIGN',                                                                  -- 初期値-
										'DELETE_DATE',                                                                  -- 初期値-
										'INSERT_USER_ID',                                                            ---初期値
										'INSERT_DATE_TIME',                                                        -- 初期値-
										'UPDATE_USER_ID',                                                            -- 初期値-
										'UPDATE_DATE_TIME');                                                      ---初期値
	defaultVals := addQuota('1') || ', '			         		                    -- CARD_HAKKO_SIGN ：有：1
						|| addQuota('0') || ', '		         		                    -- DELETE_SIGN                                                                  -- 初期値-
						|| addQuota('        ') || ', '		         		                    -- DELETE_DATE                                                                  -- 初期値-
						|| addQuota(' ')	 || ', '												--INSERT_USER_ID
						|| 'sysdate, '																--INSERT_DATE_TIME
						|| addQuota(' ')	 || ', '												--UPDATE_USER_ID
						|| 'sysdate'; 																--UPDATE_DATE_TIME
	
	colNames := getTblCols('KYK_CST_KANREN', extendCols, defaultCols);
	
	sql_str := 'INSERT /*APPEND*/ INTO KYK_CST_KANREN('				--契約顧客関連-KYK_CST_KANREN
					|| getColsWithComma(extendCols)		--INSERT対象コラム（順番指定のため、増幅項目）
					|| ', '
					|| colNames										--INSERT対象コラム（順番指定のため、増幅元データ項目）
					|| ', '
					|| getColsWithComma(defaultCols)	 	--INSERT対象コラム（順番指定のため、デフォルト値項目）
					|| ') '
	
					|| 'SELECT TO_CHAR(' || max_KEY1 || '+rownum), '			--増幅項目-KYK_CST_KANREN_NO
					|| 'TO_CHAR(' || max_MEM_NO || '+rownum), '							--増幅項目-MEM_NO
					|| 'TO_CHAR(' || max_CST_NO || '+rownum), '							--増幅項目-CST_NO
					|| 'TO_CHAR(' || max_KEY2 || '+rownum), '							--増幅項目-MOSIKOMI_NO
					|| 'TO_CHAR(' || max_CARD_NO || '+rownum), '							--増幅項目-CARD_NO
					|| colNames																			--増幅元データ項目
					|| ', '
					|| defaultVals 																		--デフォルト値項目
					|| ' FROM (SELECT ' || colNames || ' FROM KYK_CST_KANREN '		--増幅元データ項目取得
					|| ' INNER JOIN (' || specifySql || ') S1'		--絞ったデータから取得
					|| ' ON S1.KYK_CST_KANREN_NO = KYK_CST_KANREN.KYK_CST_KANREN_NO'
					|| ' ORDER BY S1.MEM_NO)';															--ソートキー指定-MEM_NO
	
	sql_str := sql_str || ' WHERE rownum <= ' || extendTargetCnt;  --件数指定（もしくは最大件数）
	
	--dbms_output.put_line(sql_str); --テスト用、SQL出力
	execute immediate sql_str;
	
	-- 増幅後総件数
	SELECT COUNT(*) INTO currentCnt FROM KYK_CST_KANREN;	
	dbms_output.put_line(logTblName || '増幅実施後総件数 : ' || currentCnt);
	
	extendCnt := currentCnt - extendCnt; --増幅件数を設定する
	dbms_output.put_line(logTblName || '増幅件数 : ' || extendCnt);

	---------------------------------------------------------
	
	---------------------------------------------------------
	-- 非カード契約顧客関連-HI_CARD_KYK_CST_KANREN
	logTblName := 'テーブル名：非カード契約顧客関連(HI_CARD_KYK_CST_KANREN)　';

	-- 増幅前総件数
	SELECT COUNT(*) INTO currentCnt FROM HI_CARD_KYK_CST_KANREN;	
	dbms_output.put_line(logTblName || '増幅実施前総件数 : ' || currentCnt);
	extendCnt := currentCnt; --増幅対象件数を設定する
	
	-- 契約顧客関連番号最大値取得
	SELECT MAX(KYK_CST_KANREN_NO) INTO max_KEY1 FROM HI_CARD_KYK_CST_KANREN;
	dbms_output.put_line(logTblName || '契約顧客関連番号最大値取得 : ' || max_KEY1);
	-- 申込番号最大値取得
	max_KEY2 := 0;
	
	extendCols := colArrays('KYK_CST_KANREN_NO',
										'MEM_NO',
										'CST_NO',
										'MOSIKOMI_NO',
										'CARD_NO');
	defaultCols := colArrays('CARD_HAKKO_SIGN',                                                        -- カード発行有サイン：有：1
										'DELETE_SIGN',                                                                  -- 初期値-
										'DELETE_DATE',                                                                  -- 初期値-
										'INSERT_USER_ID',                                                            ---初期値
										'INSERT_DATE_TIME',                                                        -- 初期値-
										'UPDATE_USER_ID',                                                            -- 初期値-
										'UPDATE_DATE_TIME');                                                      ---初期値
	defaultVals := addQuota('1') || ', '			         		                    -- CARD_HAKKO_SIGN ：有：1
						|| addQuota('0') || ', '		         		                    -- DELETE_SIGN                                                                  -- 初期値-
						|| addQuota('        ') || ', '		         		                    -- DELETE_DATE                                                                  -- 初期値-
						|| addQuota(' ')	 || ', '												--INSERT_USER_ID
						|| 'sysdate, '																--INSERT_DATE_TIME
						|| addQuota(' ')	 || ', '												--UPDATE_USER_ID
						|| 'sysdate'; 																--UPDATE_DATE_TIME
	
	colNames := getTblCols('HI_CARD_KYK_CST_KANREN', extendCols, defaultCols);
	
	sql_str := 'INSERT /*APPEND*/ INTO HI_CARD_KYK_CST_KANREN('				--非カード契約顧客関連-HI_CARD_KYK_CST_KANREN
					|| getColsWithComma(extendCols)		--INSERT対象コラム（順番指定のため、増幅項目）
					|| ', '
					|| colNames										--INSERT対象コラム（順番指定のため、増幅元データ項目）
					|| ', '
					|| getColsWithComma(defaultCols)	 	--INSERT対象コラム（順番指定のため、デフォルト値項目）
					|| ') '
	
					|| 'SELECT TO_CHAR(' || max_KEY1 || '+rownum), '			--増幅項目-KYK_CST_KANREN_NO
					|| 'TO_CHAR(' || max_MEM_NO || '+rownum), '							--増幅項目-MEM_NO
					|| 'TO_CHAR(' || max_CST_NO || '+rownum), '							--増幅項目-CST_NO
					|| 'TO_CHAR(' || max_KEY2 || '+rownum), '							--増幅項目-MOSIKOMI_NO
					|| 'TO_CHAR(' || max_CARD_NO || '+rownum), '							--増幅項目-CARD_NO
					|| colNames																			--増幅元データ項目
					|| ', '
					|| defaultVals 																		--デフォルト値項目
					|| ' FROM (SELECT ' || colNames || ' FROM HI_CARD_KYK_CST_KANREN '		--増幅元データ項目取得
					|| ' ORDER BY MEM_NO)';															--ソートキー指定-MEM_NO
	
	sql_str := sql_str || ' WHERE rownum <= ' || extendTargetCnt;  --件数指定（もしくは最大件数）
	
	--dbms_output.put_line(sql_str); --テスト用、SQL出力
	execute immediate sql_str;
	
	-- 増幅後総件数
	SELECT COUNT(*) INTO currentCnt FROM HI_CARD_KYK_CST_KANREN;	
	dbms_output.put_line(logTblName || '増幅実施後総件数 : ' || currentCnt);
	
	extendCnt := currentCnt - extendCnt; --増幅件数を設定する
	dbms_output.put_line(logTblName || '増幅件数 : ' || extendCnt);

	---------------------------------------------------------
	
	-- 増幅実施後総件数
	sql_str := 'SELECT COUNT(*) FROM (' || specifySql || ')';	
	execute immediate sql_str into currentCnt;
	dbms_output.put_line('増幅実施後総件数 : ' || currentCnt);
	
end doubleSkyTables;
/
