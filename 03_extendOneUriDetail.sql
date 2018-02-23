set serveroutput on

----------------------------------------------------------------------------------------------
-- �v���V�[�W��
----------------------------------------------------------------------------------------------
--�@�A���㖾�ׂ̑���
----------------------------------------------------------------------------------------------
create or replace procedure extendOneUriDetail(
	memNo in varchar, 						-- �����Ώۉ���ԍ�
	specifyExtendCnt in number							-- ��������
)
is
	colNames varchar(5000); 		-- ��
	
	logTblName varchar(500);	--���O�o�͗p�e�[�u����
	
	sql_str varchar(20000); 		--SQL��
	specifySql varchar(20000); 		--�i��pSQL��
	detailSql varchar(20000); 		--���חpSQL��
	originUriNo varchar(500);			--������ԍ�

	extendCols colArrays;					-- �����ΏۃR���������X�g
	defaultCols colArrays;					-- �����l�ΏۃR���������X�g
	defaultVals varchar(5000);		-- �����l�Ώۏ����l
	
    currentCnt number;         		-- ����̑�����
    extendCnt number;         		-- ��������
	
    max_URI_NO number;          						-- ����ԍ��ő�l
    max_ZAN_NO number;          						-- �c���ԍ��ő�l
	
	cardNo varchar(100);
	
    max_KEY1 number;          	-- �����p�L�[�P
    max_KEY2 number;      		-- �����p�L�[�Q
    max_KEY3 number;      		-- �����p�L�[�R
	skyYM varchar(100);			--�����N��

begin
	---------------------------------------------------------
	--���O�ݒ�l
	---------------------------------------------------------
	originUriNo := addQuota('2017101300000019');			--������ԍ�
	
	--�����N���ݒ�
	skyYM := addQuota('201809');
	---------------------------------------------------------
							   
					
	-- ����ԍ��ő�l�擾
	SELECT MAX(URI_NO) INTO max_URI_NO FROM SP_URI_DETAIL;	
	dbms_output.put_line('����ԍ��ő�l�擾 : ' || max_URI_NO);
	
	-- �c���ԍ��ő�l�擾
	SELECT MAX(ZAN_NO) INTO max_ZAN_NO FROM URI_DETAIL_ZAN;	
	dbms_output.put_line('�c���ԍ��ő�l�擾 : ' || max_ZAN_NO);
	
	--�@�J�[�h�ԍ��擾	
	SELECT MAX(CARD_NO) INTO cardNo FROM KYK_CST_KANREN WHERE MEM_NO=memNo;

	specifySql := 'SELECT ROWNUM RN FROM SP_URI_DETAIL WHERE '
					|| 'ROWNUM <= ' || specifyExtendCnt;
	
	-- �������{
	---------------------------------------------------------
	-- �V���b�s���O���㖾��-SP_URI_DETAIL_TEST
	logTblName := '�e�[�u�����F�V���b�s���O���㖾��(SP_URI_DETAIL_TEST)�@';
	
	-- ����������הԍ��ő�l�擾
	SELECT MAX(URI_NYK_DETAIL_NO) INTO max_KEY1 FROM SP_URI_DETAIL_TEST;	
	dbms_output.put_line('����������הԍ��ő�l�擾 : ' || max_KEY1);
	
	-- �����O����
	SELECT COUNT(*) INTO currentCnt FROM SP_URI_DETAIL_TEST;	
	dbms_output.put_line(logTblName || '�������{�O������ : ' || currentCnt);
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
	
	--�@���חp
	detailSql := 'SELECT ' || colNames || ' FROM SP_URI_DETAIL_TEST WHERE '
					|| 'URI_NO IN (' || originUriNo || ') ORDER BY URI_NO';	--������ԍ�
	
	
	sql_str := 'INSERT /*APPEND*/ INTO SP_URI_DETAIL_TEST('				--�V���b�s���O���㖾��-SP_URI_DETAIL_TEST
					|| getColsWithComma(extendCols)		--INSERT�ΏۃR�����i���Ԏw��̂��߁A�������ځj
					|| ', '
					|| colNames										--INSERT�ΏۃR�����i���Ԏw��̂��߁A�������f�[�^���ځj
					|| ', '
					|| getColsWithComma(defaultCols)		--INSERT�ΏۃR�����i���Ԏw��̂��߁A�f�t�H���g�l���ځj
					|| ') '
					|| 'SELECT TO_CHAR(' || max_URI_NO || '+rownum), '	--��������-URI_NO
					|| ' TO_CHAR(' || max_KEY1 || '+rownum), '					--��������-URI_NYK_DETAIL_NO
					|| ' TO_CHAR(' || max_ZAN_NO || '+rownum), '				--��������-ZAN_NO
					|| addQuota(memNo) || ', ' ||  addQuota(cardNo) || ', '
					|| colNames																	--�������f�[�^����
					|| ', '
					|| defaultVals	 															--�f�t�H���g�l����
					|| ' FROM (SELECT ' || colNames 
					|| ' FROM (' || detailSql || ') D1'												--���ו�
					|| ' CROSS JOIN (' || specifySql || ') S1)';							--�����{���A�f�J���g�ώ擾
	
	
	--dbms_output.put_line(sql_str); --�e�X�g�p�ASQL�o��
	execute immediate sql_str;
	
	-- �����㌏��
	SELECT COUNT(*) INTO currentCnt FROM SP_URI_DETAIL_TEST;	
	dbms_output.put_line(logTblName || '�������{�㑍���� : ' || currentCnt);
	extendCnt := currentCnt - extendCnt; --����������ݒ肷��
	dbms_output.put_line(logTblName || '�������� : ' || extendCnt);
	---------------------------------------------------------
	
	---------------------------------------------------------
	-- ���㖾�׎c��-URI_DETAIL_ZAN
	logTblName := '�e�[�u�����F���㖾�׎c��(URI_DETAIL_ZAN)�@';
		
	-- �����O����
	SELECT COUNT(*) INTO currentCnt FROM URI_DETAIL_ZAN;	
	dbms_output.put_line(logTblName || '�������{�O������ : ' || currentCnt);
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
	
	--�@���חp
	detailSql := 'SELECT ' || colNames || ' FROM URI_DETAIL_ZAN WHERE '
					|| 'URI_NO IN (' || originUriNo || ') ORDER BY URI_NO';	--������ԍ�
	
	
	sql_str := 'INSERT /*APPEND*/ INTO URI_DETAIL_ZAN('				--���㖾�׎c��-URI_DETAIL_ZAN
					|| getColsWithComma(extendCols)		--INSERT�ΏۃR�����i���Ԏw��̂��߁A�������ځj
					|| ', '
					|| colNames										--INSERT�ΏۃR�����i���Ԏw��̂��߁A�������f�[�^���ځj
					|| ', '
					|| getColsWithComma(defaultCols)		--INSERT�ΏۃR�����i���Ԏw��̂��߁A�f�t�H���g�l���ځj
					|| ') '
					|| 'SELECT TO_CHAR(' || max_ZAN_NO || '+rownum), '	--��������-ZAN_NO
					|| ' TO_CHAR(' || max_URI_NO || '+rownum), '				--��������-URI_NO
					|| addQuota(memNo) || ', ' ||  addQuota(cardNo) || ', '
					|| colNames																	--�������f�[�^����
					|| ', '
					|| defaultVals	 															--�f�t�H���g�l����
					|| ' FROM (SELECT ' || colNames 
					|| ' FROM (' || detailSql || ') D1'												--���ו�
					|| ' CROSS JOIN (' || specifySql || ') S1)';							--������A�f�J���g�ώ擾
	
	
	--dbms_output.put_line(sql_str); --�e�X�g�p�ASQL�o��
	execute immediate sql_str;
		
	-- �����㌏��
	SELECT COUNT(*) INTO currentCnt FROM URI_DETAIL_ZAN;	
	dbms_output.put_line(logTblName || '�������{�㑍���� : ' || currentCnt);
	extendCnt := currentCnt - extendCnt; --����������ݒ肷��
	dbms_output.put_line(logTblName || '�������� : ' || extendCnt);
	---------------------------------------------------------
	
	---------------------------------------------------------
	-- ���㖾�א����c��-URI_DETAIL_SKY_ZAN
	logTblName := '�e�[�u�����F���㖾�א����c��(URI_DETAIL_SKY_ZAN)�@';
	
		
	-- �����O����
	SELECT COUNT(*) INTO currentCnt FROM URI_DETAIL_SKY_ZAN;	
	dbms_output.put_line(logTblName || '�������{�O������ : ' || currentCnt);
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
	
	--�@���חp
	detailSql := 'SELECT ' || colNames || ' FROM URI_DETAIL_SKY_ZAN WHERE '
					|| 'URI_NO IN (' || originUriNo || ') ORDER BY URI_NO';	--������ԍ�
		
	
	sql_str := 'INSERT /*APPEND*/ INTO URI_DETAIL_SKY_ZAN('				--���㖾�א����c��-URI_DETAIL_SKY_ZAN
					|| getColsWithComma(extendCols)		--INSERT�ΏۃR�����i���Ԏw��̂��߁A�������ځj
					|| ', '
					|| colNames										--INSERT�ΏۃR�����i���Ԏw��̂��߁A�������f�[�^���ځj
					|| ', '
					|| getColsWithComma(defaultCols)		--INSERT�ΏۃR�����i���Ԏw��̂��߁A�f�t�H���g�l���ځj
					|| ') '
					|| 'SELECT TO_CHAR(' || max_ZAN_NO || '+rownum), '	--��������-ZAN_NO
					|| skyYM || ', '																--�w�萿���N��
					|| ' TO_CHAR(' || max_URI_NO || '+rownum), '				--��������-URI_NO
					|| addQuota(memNo) || ', ' ||  addQuota(cardNo) || ', '
					|| colNames																	--�������f�[�^����
					|| ', '
					|| defaultVals	 															--�f�t�H���g�l����
					|| ' FROM (SELECT ' || colNames 
					|| ' FROM (' || detailSql || ') D1'												--���ו�
					|| ' CROSS JOIN (' || specifySql || ') S1)';							--������A�f�J���g�ώ擾
	
	
	--dbms_output.put_line(sql_str); --�e�X�g�p�ASQL�o��
	execute immediate sql_str;
	-- �����㌏��
	SELECT COUNT(*) INTO currentCnt FROM URI_DETAIL_SKY_ZAN;	
	dbms_output.put_line(logTblName || '�������{�㑍���� : ' || currentCnt);
	
	extendCnt := currentCnt - extendCnt; --����������ݒ肷��
	dbms_output.put_line(logTblName || '�������� : ' || extendCnt);
	---------------------------------------------------------
	
end extendOneUriDetail;
/