set serveroutput on

----------------------------------------------------------------------------------------------
-- プロシージャ
----------------------------------------------------------------------------------------------
--　②売上明細の増幅
----------------------------------------------------------------------------------------------
create or replace procedure extendUriDetailTables(
	startMemNo in number, 						-- 増幅開始会員番号
	extendMemCnt in number					-- 増幅対象会員件数
)
is
	colNames varchar(5000); 		-- 列名
	
	logTblName varchar(500);	--ログ出力用テーブル名
	
	sql_str varchar(20000); 		--SQL文
	specifySql varchar(20000); 		--絞る用SQL文
	detailSql varchar(20000); 		--各会員の明細用SQL文
	originUriNo varchar(500);			--元売上番号
	installmentIdx number; 			--分割の売上番号の順番（10件のうち、昇順）

	extendCols colArrays;					-- 増幅対象コラム名リスト
	defaultCols colArrays;					-- 初期値対象コラム名リスト
	defaultVals varchar(5000);		-- 初期値対象初期値
	
    currentCnt number;         		-- 現状の総件数
    extendCnt number;         		-- 増幅目標件数
	
    max_URI_NO number;          						-- 売上番号最大値
    max_ZAN_NO number;          						-- 残高番号最大値
	
    max_KEY1 number;          	-- 増幅用キー１
    max_KEY2 number;      		-- 増幅用キー２
    max_KEY3 number;      		-- 増幅用キー３
	
	skyYM varchar(100);			--請求年月
	skyYMInstallment varchar(500);  --分割請求年月
	
begin
	---------------------------------------------------------
	--事前設定値
	---------------------------------------------------------
	originUriNo := addQuota('2017101300000019') || ', '	--分割の条件、1件目
					  || addQuota('2017101300000020') || ', '	--リボの条件、1件目
					  || addQuota('2017101300000021') || ', '	--一括の条件、1件目
					  || addQuota('2017101300000022') || ', '	--一括の条件、2件目
					  || addQuota('2017101300000023') || ', '	--一括の条件、3件目
					  || addQuota('2017101300000024') || ', '	--一括の条件、4件目
					  || addQuota('2017101300000025') || ', '	--一括の条件、5件目
					  || addQuota('2017101300000026') || ', '	--一括の条件、6件目
					  || addQuota('2017101300000027') || ', '	--一括の条件、7件目
					  || addQuota('2017101300000028');			--一括の条件、8件目
	installmentIdx := 2;													--分割の件目
	
	--請求年月設定
	skyYM := addQuota('202809');
	skyYMInstallment :=  'SELECT ' || addQuota('202810') || ' IN_SKY_YM FROM DUAL UNION ALL '
	--							|| 'SELECT ' || addQuota('202811') || ' IN_SKY_YM FROM DUAL UNION ALL '
	--							|| 'SELECT ' || addQuota('202812') || ' IN_SKY_YM FROM DUAL UNION ALL '
	--							|| 'SELECT ' || addQuota('202901') || ' IN_SKY_YM FROM DUAL UNION ALL '
	--							|| 'SELECT ' || addQuota('202902') || ' IN_SKY_YM FROM DUAL UNION ALL '
	--							|| 'SELECT ' || addQuota('202903') || ' IN_SKY_YM FROM DUAL UNION ALL '
	--							|| 'SELECT ' || addQuota('202904') || ' IN_SKY_YM FROM DUAL UNION ALL '
	--							|| 'SELECT ' || addQuota('202905') || ' IN_SKY_YM FROM DUAL UNION ALL '
								|| 'SELECT ' || addQuota('202906') || ' IN_SKY_YM FROM DUAL';		--9件、1件は追加済み
	---------------------------------------------------------
							   
					
	-- 売上番号最大値取得
	SELECT MAX(URI_NO) INTO max_URI_NO FROM SP_URI_DETAIL;	
	dbms_output.put_line('売上番号最大値取得 : ' || max_URI_NO);
	
	-- 残高番号最大値取得
	SELECT MAX(ZAN_NO) INTO max_ZAN_NO FROM URI_DETAIL_ZAN;	
	dbms_output.put_line('残高番号最大値取得 : ' || max_ZAN_NO);
	
	--　会員絞る用
	specifySql := 'SELECT MEM_NO,CARD_NO FROM KYK_CST_KANREN WHERE '
					|| 'DELETE_SIGN=' || addQuota('0')
					|| ' AND MEM_NO > '  || addQuota(startMemNo)
					|| ' AND MEM_NO <= '  || addQuota(startMemNo+extendMemCnt)
					|| ' ORDER BY MEM_NO';
	
	-- 絞っている会員件数
	sql_str := 'SELECT COUNT(*) FROM (' || specifySql || ')';
	execute immediate sql_str into currentCnt;
	dbms_output.put_line('絞っている会員件数 : ' || currentCnt);
	
	-- 増幅実施
	---------------------------------------------------------
	-- ショッピング売上明細-SP_URI_DETAIL
	logTblName := 'テーブル名：ショッピング売上明細(SP_URI_DETAIL)　';
	
	-- 売上入金明細番号最大値取得
	SELECT MAX(URI_NYK_DETAIL_NO) INTO max_KEY1 FROM SP_URI_DETAIL;	
	dbms_output.put_line('売上入金明細番号最大値取得 : ' || max_KEY1);
	
	-- 増幅前件数
	SELECT COUNT(*) INTO currentCnt FROM SP_URI_DETAIL;	
	dbms_output.put_line(logTblName || '増幅実施前総件数 : ' || currentCnt);
	extendCnt := currentCnt; 
		
	extendCols := colArrays('URI_NO',
								'URI_NYK_DETAIL_NO',
								'ZAN_NO',
								'MEM_NO',
								'CARD_NO');
	defaultCols := colArrays('DELETE_SIGN',
								'INSERT_USER_ID',
								'INSERT_DATE_TIME',
								'UPDATE_USER_ID',
								'UPDATE_DATE_TIME');
	defaultVals := addQuota('0') || ', '			--DELETE_SIGN
						|| addQuota(' ')	 || ', '		--INSERT_USER_ID
						|| 'sysdate, '						--INSERT_DATE_TIME
						|| addQuota(' ')	 || ', '		--UPDATE_USER_ID
						|| 'sysdate'; 				--UPDATE_DATE_TIME
	
	colNames := getTblCols('SP_URI_DETAIL', extendCols, defaultCols);
	
	--　明細用
	detailSql := 'SELECT ' || colNames || ' FROM SP_URI_DETAIL WHERE '
					|| 'URI_NO IN (' || originUriNo || ') ORDER BY URI_NO';	--元売上番号
	
	sql_str := 'SELECT COUNT(*) FROM (' || detailSql || ')';
	
	--dbms_output.put_line(sql_str); --テスト用、SQL出力
	
	execute immediate sql_str into currentCnt;
	dbms_output.put_line(logTblName || '各会員の増幅明細件数 : ' || currentCnt);
	
	
	sql_str := 'INSERT /*APPEND*/ INTO SP_URI_DETAIL('				--ショッピング売上明細-SP_URI_DETAIL
					|| getColsWithComma(extendCols)		--INSERT対象コラム（順番指定のため、増幅項目）
					|| ', '
					|| colNames										--INSERT対象コラム（順番指定のため、増幅元データ項目）
					|| ', '
					|| getColsWithComma(defaultCols)		--INSERT対象コラム（順番指定のため、デフォルト値項目）
					|| ') '
					|| 'SELECT TO_CHAR(' || max_URI_NO || '+rownum), '	--増幅項目-URI_NO
					|| ' TO_CHAR(' || max_KEY1 || '+rownum), '					--増幅項目-URI_NYK_DETAIL_NO
					|| ' TO_CHAR(' || max_ZAN_NO || '+rownum), '				--増幅項目-ZAN_NO
					|| 'MEM_NO, CARD_NO, '
					|| colNames																	--増幅元データ項目
					|| ', '
					|| defaultVals	 															--デフォルト値項目
					|| ' FROM (SELECT ' || colNames 
					|| ', S1.MEM_NO MEM_NO, S1.CARD_NO CARD_NO '
					|| ' FROM (' || detailSql || ') D1'												--明細分
					|| ' CROSS JOIN (' || specifySql || ') S1'							--会員分、デカルト積取得
					|| ' ORDER BY S1.MEM_NO)';											--ソートキー指定-MEM_NO
	
	
	--dbms_output.put_line(sql_str); --テスト用、SQL出力
	execute immediate sql_str;
	
	-- 増幅後件数
	SELECT COUNT(*) INTO currentCnt FROM SP_URI_DETAIL;	
	dbms_output.put_line(logTblName || '増幅実施後総件数 : ' || currentCnt);
	extendCnt := currentCnt - extendCnt; --増幅件数を設定する
	dbms_output.put_line(logTblName || '増幅件数 : ' || extendCnt);
	---------------------------------------------------------
	
	---------------------------------------------------------
	-- 売上明細残高-URI_DETAIL_ZAN
	logTblName := 'テーブル名：売上明細残高(URI_DETAIL_ZAN)　';
		
	-- 増幅前件数
	SELECT COUNT(*) INTO currentCnt FROM URI_DETAIL_ZAN;	
	dbms_output.put_line(logTblName || '増幅実施前総件数 : ' || currentCnt);
	extendCnt := currentCnt; 
		
	extendCols := colArrays('ZAN_NO',
								'URI_NO',
								'MEM_NO',
								'CARD_NO');
	defaultCols := colArrays('INSERT_USER_ID',
								'INSERT_DATE_TIME',
								'UPDATE_USER_ID',
								'UPDATE_DATE_TIME');
	defaultVals := addQuota(' ')	 || ', '		--INSERT_USER_ID
						|| 'sysdate, '						--INSERT_DATE_TIME
						|| addQuota(' ')	 || ', '		--UPDATE_USER_ID
						|| 'sysdate'; 				--UPDATE_DATE_TIME
	
	colNames := getTblCols('URI_DETAIL_ZAN', extendCols, defaultCols);
	
	--　明細用
	detailSql := 'SELECT ' || colNames || ' FROM URI_DETAIL_ZAN WHERE '
					|| 'ZAN_NO IN (SELECT MAX(ZAN_NO) FROM URI_DETAIL_ZAN WHERE '		--唯一性
					|| 'URI_NO IN (' || originUriNo || ') GROUP BY URI_NO) ORDER BY URI_NO';	--元売上番号
	
	sql_str := 'SELECT COUNT(*) FROM (' || detailSql || ')';
	
	--dbms_output.put_line(sql_str); --テスト用、SQL出力
	
	execute immediate sql_str into currentCnt;
	dbms_output.put_line(logTblName || '各会員の増幅明細件数 : ' || currentCnt);
	
	
	sql_str := 'INSERT /*APPEND*/ INTO URI_DETAIL_ZAN('				--売上明細残高-URI_DETAIL_ZAN
					|| getColsWithComma(extendCols)		--INSERT対象コラム（順番指定のため、増幅項目）
					|| ', '
					|| colNames										--INSERT対象コラム（順番指定のため、増幅元データ項目）
					|| ', '
					|| getColsWithComma(defaultCols)		--INSERT対象コラム（順番指定のため、デフォルト値項目）
					|| ') '
					|| 'SELECT TO_CHAR(' || max_ZAN_NO || '+rownum), '	--増幅項目-ZAN_NO
					|| ' TO_CHAR(' || max_URI_NO || '+rownum), '				--増幅項目-URI_NO
					|| 'MEM_NO, CARD_NO, '
					|| colNames																	--増幅元データ項目
					|| ', '
					|| defaultVals	 															--デフォルト値項目
					|| ' FROM (SELECT ' || colNames 
					|| ', S1.MEM_NO MEM_NO, S1.CARD_NO CARD_NO '
					|| ' FROM (' || detailSql || ') D1'												--明細分
					|| ' CROSS JOIN (' || specifySql || ') S1'							--会員分、デカルト積取得
					|| ' ORDER BY S1.MEM_NO)';											--ソートキー指定-MEM_NO
	
	
	--dbms_output.put_line(sql_str); --テスト用、SQL出力
	execute immediate sql_str;
		
	-- 増幅後件数
	SELECT COUNT(*) INTO currentCnt FROM URI_DETAIL_ZAN;	
	dbms_output.put_line(logTblName || '増幅実施後総件数 : ' || currentCnt);
	extendCnt := currentCnt - extendCnt; --増幅件数を設定する
	dbms_output.put_line(logTblName || '増幅件数 : ' || extendCnt);
	---------------------------------------------------------
	
	---------------------------------------------------------
	-- 売上明細請求残高-URI_DETAIL_SKY_ZAN
	logTblName := 'テーブル名：売上明細請求残高(URI_DETAIL_SKY_ZAN)　';
	
		
	-- 増幅前件数
	SELECT COUNT(*) INTO currentCnt FROM URI_DETAIL_SKY_ZAN;	
	dbms_output.put_line(logTblName || '増幅実施前総件数 : ' || currentCnt);
	extendCnt := currentCnt; 
		
	extendCols := colArrays('ZAN_NO',
								'SKY_YM',
								'URI_NO',
								'MEM_NO',
								'CARD_NO');
	defaultCols := colArrays('INSERT_USER_ID',
								'INSERT_DATE_TIME',
								'UPDATE_USER_ID',
								'UPDATE_DATE_TIME');
	defaultVals := addQuota(' ')	 || ', '		--INSERT_USER_ID
						|| 'sysdate, '						--INSERT_DATE_TIME
						|| addQuota(' ')	 || ', '		--UPDATE_USER_ID
						|| 'sysdate'; 				--UPDATE_DATE_TIME
	
	colNames := getTblCols('URI_DETAIL_SKY_ZAN', extendCols, defaultCols);
	
	--　明細用
	detailSql := 'SELECT ' || colNames || ' FROM URI_DETAIL_SKY_ZAN M1 INNER JOIN '
					|| '(SELECT MAX(ZAN_NO) ZN, MAX(SKY_YM) YM, URI_NO UN FROM URI_DETAIL_SKY_ZAN WHERE '
					|| 'URI_NO IN (' || originUriNo || ') GROUP BY URI_NO) S1 '	--元売上番号
					|| 'ON M1.URI_NO=S1.UN AND M1.ZAN_NO=ZN AND M1.SKY_YM=S1.YM ORDER BY URI_NO'; --唯一性
	
	sql_str := 'SELECT COUNT(*) FROM (' || detailSql || ')';
	
	--dbms_output.put_line(sql_str); --テスト用、SQL出力
	
	execute immediate sql_str into currentCnt;
	dbms_output.put_line(logTblName || '各会員の増幅明細件数 : ' || currentCnt);
	
	
	sql_str := 'INSERT /*APPEND*/ INTO URI_DETAIL_SKY_ZAN('				--売上明細請求残高-URI_DETAIL_SKY_ZAN
					|| getColsWithComma(extendCols)		--INSERT対象コラム（順番指定のため、増幅項目）
					|| ', '
					|| colNames										--INSERT対象コラム（順番指定のため、増幅元データ項目）
					|| ', '
					|| getColsWithComma(defaultCols)		--INSERT対象コラム（順番指定のため、デフォルト値項目）
					|| ') '
					|| 'SELECT TO_CHAR(' || max_ZAN_NO || '+rownum), '	--増幅項目-ZAN_NO
					|| skyYM || ', '																--指定請求年月
					|| ' TO_CHAR(' || max_URI_NO || '+rownum), '				--増幅項目-URI_NO
					|| 'MEM_NO, CARD_NO, '
					|| colNames																	--増幅元データ項目
					|| ', '
					|| defaultVals	 															--デフォルト値項目
					|| ' FROM (SELECT ' || colNames 
					|| ', S1.MEM_NO MEM_NO, S1.CARD_NO CARD_NO '
					|| ' FROM (' || detailSql || ') D1'												--明細分
					|| ' CROSS JOIN (' || specifySql || ') S1'							--会員分、デカルト積取得
					|| ' ORDER BY S1.MEM_NO)';											--ソートキー指定-MEM_NO
	
	
	--dbms_output.put_line(sql_str); --テスト用、SQL出力
	execute immediate sql_str;
	SELECT COUNT(*) INTO currentCnt FROM URI_DETAIL_SKY_ZAN;	
	dbms_output.put_line(logTblName || '増幅実施後総件数（分割分以外） : ' || currentCnt);
	
	--分割分追加	
	specifySql := 'SELECT ZAN_NO, URI_NO, MEM_NO, CARD_NO, ' || colNames || ' FROM URI_DETAIL_SKY_ZAN WHERE '
					|| 'MOD(URI_NO - ' || max_URI_NO || ', 10) =' || installmentIdx || ' ORDER BY URI_NO';	 --分割分のみ取得
	detailSql := 'SELECT IN_SKY_YM FROM (' || skyYMInstallment || ')';
	
	sql_str := 'INSERT /*APPEND*/ INTO URI_DETAIL_SKY_ZAN('				--売上明細請求残高-URI_DETAIL_SKY_ZAN
					|| getColsWithComma(extendCols)		--INSERT対象コラム（順番指定のため、増幅項目）
					|| ', '
					|| colNames										--INSERT対象コラム（順番指定のため、増幅元データ項目）
					|| ', '
					|| getColsWithComma(defaultCols)		--INSERT対象コラム（順番指定のため、デフォルト値項目）
					|| ') '
					|| 'SELECT ZAN_NO, IN_SKY_YM, '						--ZAN_NO、SKY_YM
					|| 'URI_NO, MEM_NO, CARD_NO, '
					|| colNames																	--増幅元データ項目
					|| ', '
					|| defaultVals	 															--デフォルト値項目
					|| ' FROM (SELECT ' || colNames 
					|| ', D1.IN_SKY_YM IN_SKY_YM '
					|| ', S1.ZAN_NO ZAN_NO, S1.URI_NO URI_NO, S1.MEM_NO MEM_NO, S1.CARD_NO CARD_NO '
					|| ' FROM (' || detailSql || ') D1'												--明細分
					|| ' CROSS JOIN (' || specifySql || ') S1)';							--デカルト積取得
	
	
	--dbms_output.put_line(sql_str); --テスト用、SQL出力
	execute immediate sql_str;
	
	-- 増幅後件数
	SELECT COUNT(*) INTO currentCnt FROM URI_DETAIL_SKY_ZAN;	
	dbms_output.put_line(logTblName || '増幅実施後総件数 : ' || currentCnt);
	extendCnt := currentCnt - extendCnt; --増幅件数を設定する
	dbms_output.put_line(logTblName || '増幅件数 : ' || extendCnt);
	---------------------------------------------------------
	
end extendUriDetailTables;
/
