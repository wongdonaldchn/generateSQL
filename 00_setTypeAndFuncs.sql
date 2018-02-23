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
	
	--dbms_output.put_line('テーブルの列名取得 : ' || tableName);
	
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