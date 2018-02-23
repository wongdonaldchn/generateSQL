set serveroutput on

----------------------------------------------------------------------------------------------
-- プロシージャ
----------------------------------------------------------------------------------------------
--　②売上明細の増幅
----------------------------------------------------------------------------------------------
create or replace procedure extendOneUriDetail(
	memNo in varchar, 						-- 増幅対象会員番号
	specifyExtendCnt in number							-- 増幅件数
)
is
	colNames varchar(5000); 		-- 列名
	
	logTblName varchar(500);	--ログ出力用テーブル名
	
	sql_str varchar(20000); 		--SQL文
	specifySql varchar(20000); 		--絞る用SQL文
	detailSql varchar(20000); 		--明細用SQL文
	originUriNo varchar(500);			--元売上番号

	extendCols colArrays;					-- 増幅対象コラム名リスト
	defaultCols colArrays;					-- 初期値対象コラム名リスト
	defaultVals varchar(5000);		-- 初期値対象初期値
	
    currentCnt number;         		-- 現状の総件数
    extendCnt number;         		-- 増幅件数
	
    max_URI_NO number;          						-- 売上番号最大値
    max_ZAN_NO number;          						-- 残高番号最大値
	
	cardNo varchar(100);
	
    max_KEY1 number;          	-- 増幅用キー１
    max_KEY2 number;      		-- 増幅用キー２
    max_KEY3 number;      		-- 増幅用キー３
	skyYM varchar(100);			--請求年月

begin
	---------------------------------------------------------
	--事前設定値
	---------------------------------------------------------
	originUriNo := addQuota('2017101300000019');			--元売上番号
	
	--請求年月設定
	skyYM := addQuota('201809');
	---------------------------------------------------------
							   
					
	-- 売上番号最大値取得
	SELECT MAX(URI_NO) INTO max_URI_NO FROM SP_URI_DETAIL;	
	dbms_output.put_line('売上番号最大値取得 : ' || max_URI_NO);
	
	-- 残高番号最大値取得
	SELECT MAX(ZAN_NO) INTO max_ZAN_NO FROM URI_DETAIL_ZAN;	
	dbms_output.put_line('残高番号最大値取得 : ' || max_ZAN_NO);
	
	--　カード番号取得	
	SELECT MAX(CARD_NO) INTO cardNo FROM KYK_CST_KANREN WHERE MEM_NO=memNo;

	specifySql := 'SELECT ROWNUM RN FROM SP_URI_DETAIL WHERE '
					|| 'ROWNUM <= ' || specifyExtendCnt;
	
	-- 増幅実施
	---------------------------------------------------------
	-- ショッピング売上明細-SP_URI_DETAIL_TEST
	logTblName := 'テーブル名：ショッピング売上明細(SP_URI_DETAIL_TEST)　';
	
	-- 売上入金明細番号最大値取得
	SELECT MAX(URI_NYK_DETAIL_NO) INTO max_KEY1 FROM SP_URI_DETAIL_TEST;	
	dbms_output.put_line('売上入金明細番号最大値取得 : ' || max_KEY1);
	
	-- 増幅前件数
	SELECT COUNT(*) INTO currentCnt FROM SP_URI_DETAIL_TEST;	
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
	
	colNames := getTblCols('SP_URI_DETAIL_TEST', extendCols, defaultCols);
	
	--　明細用
	detailSql := 'SELECT ' || colNames || ' FROM SP_URI_DETAIL_TEST WHERE '
					|| 'URI_NO IN (' || originUriNo || ') ORDER BY URI_NO';	--元売上番号
	
	
	sql_str := 'INSERT /*APPEND*/ INTO SP_URI_DETAIL_TEST('				--ショッピング売上明細-SP_URI_DETAIL_TEST
					|| getColsWithComma(extendCols)		--INSERT対象コラム（順番指定のため、増幅項目）
					|| ', '
					|| colNames										--INSERT対象コラム（順番指定のため、増幅元データ項目）
					|| ', '
					|| getColsWithComma(defaultCols)		--INSERT対象コラム（順番指定のため、デフォルト値項目）
					|| ') '
					|| 'SELECT TO_CHAR(' || max_URI_NO || '+rownum), '	--増幅項目-URI_NO
					|| ' TO_CHAR(' || max_KEY1 || '+rownum), '					--増幅項目-URI_NYK_DETAIL_NO
					|| ' TO_CHAR(' || max_ZAN_NO || '+rownum), '				--増幅項目-ZAN_NO
					|| addQuota(memNo) || ', ' ||  addQuota(cardNo) || ', '
					|| colNames																	--増幅元データ項目
					|| ', '
					|| defaultVals	 															--デフォルト値項目
					|| ' FROM (SELECT ' || colNames 
					|| ' FROM (' || detailSql || ') D1'												--明細分
					|| ' CROSS JOIN (' || specifySql || ') S1)';							--増幅倍数、デカルト積取得
	
	
	--dbms_output.put_line(sql_str); --テスト用、SQL出力
	execute immediate sql_str;
	
	-- 増幅後件数
	SELECT COUNT(*) INTO currentCnt FROM SP_URI_DETAIL_TEST;	
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
					|| 'URI_NO IN (' || originUriNo || ') ORDER BY URI_NO';	--元売上番号
	
	
	sql_str := 'INSERT /*APPEND*/ INTO URI_DETAIL_ZAN('				--売上明細残高-URI_DETAIL_ZAN
					|| getColsWithComma(extendCols)		--INSERT対象コラム（順番指定のため、増幅項目）
					|| ', '
					|| colNames										--INSERT対象コラム（順番指定のため、増幅元データ項目）
					|| ', '
					|| getColsWithComma(defaultCols)		--INSERT対象コラム（順番指定のため、デフォルト値項目）
					|| ') '
					|| 'SELECT TO_CHAR(' || max_ZAN_NO || '+rownum), '	--増幅項目-ZAN_NO
					|| ' TO_CHAR(' || max_URI_NO || '+rownum), '				--増幅項目-URI_NO
					|| addQuota(memNo) || ', ' ||  addQuota(cardNo) || ', '
					|| colNames																	--増幅元データ項目
					|| ', '
					|| defaultVals	 															--デフォルト値項目
					|| ' FROM (SELECT ' || colNames 
					|| ' FROM (' || detailSql || ') D1'												--明細分
					|| ' CROSS JOIN (' || specifySql || ') S1)';							--会員分、デカルト積取得
	
	
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
	detailSql := 'SELECT ' || colNames || ' FROM URI_DETAIL_SKY_ZAN WHERE '
					|| 'URI_NO IN (' || originUriNo || ') ORDER BY URI_NO';	--元売上番号
		
	
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
					|| addQuota(memNo) || ', ' ||  addQuota(cardNo) || ', '
					|| colNames																	--増幅元データ項目
					|| ', '
					|| defaultVals	 															--デフォルト値項目
					|| ' FROM (SELECT ' || colNames 
					|| ' FROM (' || detailSql || ') D1'												--明細分
					|| ' CROSS JOIN (' || specifySql || ') S1)';							--会員分、デカルト積取得
	
	
	--dbms_output.put_line(sql_str); --テスト用、SQL出力
	execute immediate sql_str;
	-- 増幅後件数
	SELECT COUNT(*) INTO currentCnt FROM URI_DETAIL_SKY_ZAN;	
	dbms_output.put_line(logTblName || '増幅実施後総件数 : ' || currentCnt);
	
	extendCnt := currentCnt - extendCnt; --増幅件数を設定する
	dbms_output.put_line(logTblName || '増幅件数 : ' || extendCnt);
	---------------------------------------------------------
	
end extendOneUriDetail;
/