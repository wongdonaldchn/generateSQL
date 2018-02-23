set serveroutput on

----------------------------------------------------------------------------------------------
-- �v���V�[�W��
----------------------------------------------------------------------------------------------
--�@�@�P���P�Ǝ�L�[�ł̔{�����ʃv���V�[�W��
----------------------------------------------------------------------------------------------
create or replace procedure doubleTblsByNameAndKey(
	tableName in varchar, 					-- �e�[�u����
	pk in varchar,								-- ��L�[
	startValue in number,					-- �J�n�l�i��L�[�̊J�n�l���w�肷��A�J�n�l�̓e�[�u���̍ő�l��菬�����ꍇ�A�e�[�u���̍ő�l��p����j
	toExtendCnt in number					-- �����w�茏���i���f�[�^�̌������傫���̏ꍇ�͌��f�[�^�ɂ�葝���j
)
is
	extendCols colArrays;					-- �����ΏۃR���������X�g
	colNames varchar(5000); 			-- ��
		
	sql_str varchar(20000); 			-- SQL��
	
    currentCnt number;        			-- ����̑�����
    maxID number;          				-- ID�ő�l
begin

	dbms_output.put_line('�e�[�u��: ' || tableName);
	
	-- �����ΏۃR����
	extendCols := colArrays(pk);
	-- ���f�[�^�ΏۃR�����擾	
	colNames := getTblCols(tableName, extendCols, colArrays(' '));
	
	-- ��L�[�ő�l�擾
	sql_str := 'SELECT MAX(' || extendCols(1) || ') FROM ' || tableName;	
	execute immediate sql_str into maxID;
	dbms_output.put_line('�����O��L�[�ő�l : ' || maxID);
	dbms_output.put_line('�w��J�n�l : ' || startValue);
	if (maxID < startValue) then
		maxID := startValue;
		dbms_output.put_line('��L�[�̑����J�n�l : ' || maxID);
	end if;
	
	-- �����Ώی���
	sql_str := 'SELECT COUNT(*) FROM ' || tableName;	
	execute immediate sql_str into currentCnt;
	dbms_output.put_line('�����Ώی��� : ' || currentCnt);
	
	-- �������{
	sql_str := 'INSERT /*APPEND*/ INTO ' || tableName || '('
					|| getColsWithComma(extendCols)	 --INSERT�ΏۃR�����i���Ԏw��̂��߁A�������ځj
					|| ', '
					|| colNames									 --INSERT�ΏۃR�����i���Ԏw��̂��߁A�������f�[�^���ځj
					|| ') '
					
					|| 'SELECT TO_CHAR(' || maxID || '+rownum), '		--�������ځj
					|| colNames											--�������f�[�^����
					|| ' FROM (SELECT ' || colNames || ' FROM ' || tableName	--�������f�[�^���ڎ擾
					|| ' ORDER BY ' || extendCols(1) || ')';							--�\�[�g�L�[�w��
					
	sql_str := sql_str || ' WHERE rownum <= ' || toExtendCnt;  --�����w��i�������͍ő匏���j
	
	
	--dbms_output.put_line(sql_str); --�e�X�g�p�ASQL�o��
	execute immediate sql_str;
	
	-- �������{�㑍����
	sql_str := 'SELECT COUNT(*) FROM ' || tableName;	
	execute immediate sql_str into currentCnt;
	dbms_output.put_line('�������{�㑍���� : ' || currentCnt);
	
end doubleTblsByNameAndKey;
/