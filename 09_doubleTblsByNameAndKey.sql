set serveroutput on

----------------------------------------------------------------------------------------------
-- プロシージャ
----------------------------------------------------------------------------------------------
--　①単純単独主キーでの倍増共通プロシージャ
----------------------------------------------------------------------------------------------
create or replace procedure doubleTblsByNameAndKey(
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
	
end doubleTblsByNameAndKey;
/