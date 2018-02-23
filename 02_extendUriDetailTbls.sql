set serveroutput on

----------------------------------------------------------------------------------------------
-- �v���V�[�W��
----------------------------------------------------------------------------------------------
--�@�A���㖾�ׂ̑���
----------------------------------------------------------------------------------------------
create or replace procedure extendUriDetailTables(
	startMemNo in number, 						-- �����J�n����ԍ�
	extendMemCnt in number					-- �����Ώۉ������
)
is
	colNames varchar(5000); 		-- ��
	
	logTblName varchar(500);	--���O�o�͗p�e�[�u����
	
	sql_str varchar(20000); 		--SQL��
	specifySql varchar(20000); 		--�i��pSQL��
	detailSql varchar(20000); 		--�e����̖��חpSQL��
	originUriNo varchar(500);			--������ԍ�
	installmentIdx number; 			--�����̔���ԍ��̏��ԁi10���̂����A�����j

	extendCols colArrays;					-- �����ΏۃR���������X�g
	defaultCols colArrays;					-- �����l�ΏۃR���������X�g
	defaultVals varchar(5000);		-- �����l�Ώۏ����l
	
    currentCnt number;         		-- ����̑�����
    extendCnt number;         		-- �����ڕW����
	
    max_URI_NO number;          						-- ����ԍ��ő�l
    max_ZAN_NO number;          						-- �c���ԍ��ő�l
	
    max_KEY1 number;          	-- �����p�L�[�P
    max_KEY2 number;      		-- �����p�L�[�Q
    max_KEY3 number;      		-- �����p�L�[�R
	
	skyYM varchar(100);			--�����N��
	skyYMInstallment varchar(500);  --���������N��
	
begin
	---------------------------------------------------------
	--���O�ݒ�l
	---------------------------------------------------------
	originUriNo := addQuota('2017101300000019') || ', '	--�����̏����A1����
					  || addQuota('2017101300000020') || ', '	--���{�̏����A1����
					  || addQuota('2017101300000021') || ', '	--�ꊇ�̏����A1����
					  || addQuota('2017101300000022') || ', '	--�ꊇ�̏����A2����
					  || addQuota('2017101300000023') || ', '	--�ꊇ�̏����A3����
					  || addQuota('2017101300000024') || ', '	--�ꊇ�̏����A4����
					  || addQuota('2017101300000025') || ', '	--�ꊇ�̏����A5����
					  || addQuota('2017101300000026') || ', '	--�ꊇ�̏����A6����
					  || addQuota('2017101300000027') || ', '	--�ꊇ�̏����A7����
					  || addQuota('2017101300000028');			--�ꊇ�̏����A8����
	installmentIdx := 2;													--�����̌���
	
	--�����N���ݒ�
	skyYM := addQuota('202809');
	skyYMInstallment :=  'SELECT ' || addQuota('202810') || ' IN_SKY_YM FROM DUAL UNION ALL '
	--							|| 'SELECT ' || addQuota('202811') || ' IN_SKY_YM FROM DUAL UNION ALL '
	--							|| 'SELECT ' || addQuota('202812') || ' IN_SKY_YM FROM DUAL UNION ALL '
	--							|| 'SELECT ' || addQuota('202901') || ' IN_SKY_YM FROM DUAL UNION ALL '
	--							|| 'SELECT ' || addQuota('202902') || ' IN_SKY_YM FROM DUAL UNION ALL '
	--							|| 'SELECT ' || addQuota('202903') || ' IN_SKY_YM FROM DUAL UNION ALL '
	--							|| 'SELECT ' || addQuota('202904') || ' IN_SKY_YM FROM DUAL UNION ALL '
	--							|| 'SELECT ' || addQuota('202905') || ' IN_SKY_YM FROM DUAL UNION ALL '
								|| 'SELECT ' || addQuota('202906') || ' IN_SKY_YM FROM DUAL';		--9���A1���͒ǉ��ς�
	---------------------------------------------------------
							   
					
	-- ����ԍ��ő�l�擾
	SELECT MAX(URI_NO) INTO max_URI_NO FROM SP_URI_DETAIL;	
	dbms_output.put_line('����ԍ��ő�l�擾 : ' || max_URI_NO);
	
	-- �c���ԍ��ő�l�擾
	SELECT MAX(ZAN_NO) INTO max_ZAN_NO FROM URI_DETAIL_ZAN;	
	dbms_output.put_line('�c���ԍ��ő�l�擾 : ' || max_ZAN_NO);
	
	--�@����i��p
	specifySql := 'SELECT MEM_NO,CARD_NO FROM KYK_CST_KANREN WHERE '
					|| 'DELETE_SIGN=' || addQuota('0')
					|| ' AND MEM_NO > '  || addQuota(startMemNo)
					|| ' AND MEM_NO <= '  || addQuota(startMemNo+extendMemCnt)
					|| ' ORDER BY MEM_NO';
	
	-- �i���Ă���������
	sql_str := 'SELECT COUNT(*) FROM (' || specifySql || ')';
	execute immediate sql_str into currentCnt;
	dbms_output.put_line('�i���Ă��������� : ' || currentCnt);
	
	-- �������{
	---------------------------------------------------------
	-- �V���b�s���O���㖾��-SP_URI_DETAIL
	logTblName := '�e�[�u�����F�V���b�s���O���㖾��(SP_URI_DETAIL)�@';
	
	-- ����������הԍ��ő�l�擾
	SELECT MAX(URI_NYK_DETAIL_NO) INTO max_KEY1 FROM SP_URI_DETAIL;	
	dbms_output.put_line('����������הԍ��ő�l�擾 : ' || max_KEY1);
	
	-- �����O����
	SELECT COUNT(*) INTO currentCnt FROM SP_URI_DETAIL;	
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
	
	colNames := getTblCols('SP_URI_DETAIL', extendCols, defaultCols);
	
	--�@���חp
	detailSql := 'SELECT ' || colNames || ' FROM SP_URI_DETAIL WHERE '
					|| 'URI_NO IN (' || originUriNo || ') ORDER BY URI_NO';	--������ԍ�
	
	sql_str := 'SELECT COUNT(*) FROM (' || detailSql || ')';
	
	--dbms_output.put_line(sql_str); --�e�X�g�p�ASQL�o��
	
	execute immediate sql_str into currentCnt;
	dbms_output.put_line(logTblName || '�e����̑������׌��� : ' || currentCnt);
	
	
	sql_str := 'INSERT /*APPEND*/ INTO SP_URI_DETAIL('				--�V���b�s���O���㖾��-SP_URI_DETAIL
					|| getColsWithComma(extendCols)		--INSERT�ΏۃR�����i���Ԏw��̂��߁A�������ځj
					|| ', '
					|| colNames										--INSERT�ΏۃR�����i���Ԏw��̂��߁A�������f�[�^���ځj
					|| ', '
					|| getColsWithComma(defaultCols)		--INSERT�ΏۃR�����i���Ԏw��̂��߁A�f�t�H���g�l���ځj
					|| ') '
					|| 'SELECT TO_CHAR(' || max_URI_NO || '+rownum), '	--��������-URI_NO
					|| ' TO_CHAR(' || max_KEY1 || '+rownum), '					--��������-URI_NYK_DETAIL_NO
					|| ' TO_CHAR(' || max_ZAN_NO || '+rownum), '				--��������-ZAN_NO
					|| 'MEM_NO, CARD_NO, '
					|| colNames																	--�������f�[�^����
					|| ', '
					|| defaultVals	 															--�f�t�H���g�l����
					|| ' FROM (SELECT ' || colNames 
					|| ', S1.MEM_NO MEM_NO, S1.CARD_NO CARD_NO '
					|| ' FROM (' || detailSql || ') D1'												--���ו�
					|| ' CROSS JOIN (' || specifySql || ') S1'							--������A�f�J���g�ώ擾
					|| ' ORDER BY S1.MEM_NO)';											--�\�[�g�L�[�w��-MEM_NO
	
	
	--dbms_output.put_line(sql_str); --�e�X�g�p�ASQL�o��
	execute immediate sql_str;
	
	-- �����㌏��
	SELECT COUNT(*) INTO currentCnt FROM SP_URI_DETAIL;	
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
					|| 'ZAN_NO IN (SELECT MAX(ZAN_NO) FROM URI_DETAIL_ZAN WHERE '		--�B�ꐫ
					|| 'URI_NO IN (' || originUriNo || ') GROUP BY URI_NO) ORDER BY URI_NO';	--������ԍ�
	
	sql_str := 'SELECT COUNT(*) FROM (' || detailSql || ')';
	
	--dbms_output.put_line(sql_str); --�e�X�g�p�ASQL�o��
	
	execute immediate sql_str into currentCnt;
	dbms_output.put_line(logTblName || '�e����̑������׌��� : ' || currentCnt);
	
	
	sql_str := 'INSERT /*APPEND*/ INTO URI_DETAIL_ZAN('				--���㖾�׎c��-URI_DETAIL_ZAN
					|| getColsWithComma(extendCols)		--INSERT�ΏۃR�����i���Ԏw��̂��߁A�������ځj
					|| ', '
					|| colNames										--INSERT�ΏۃR�����i���Ԏw��̂��߁A�������f�[�^���ځj
					|| ', '
					|| getColsWithComma(defaultCols)		--INSERT�ΏۃR�����i���Ԏw��̂��߁A�f�t�H���g�l���ځj
					|| ') '
					|| 'SELECT TO_CHAR(' || max_ZAN_NO || '+rownum), '	--��������-ZAN_NO
					|| ' TO_CHAR(' || max_URI_NO || '+rownum), '				--��������-URI_NO
					|| 'MEM_NO, CARD_NO, '
					|| colNames																	--�������f�[�^����
					|| ', '
					|| defaultVals	 															--�f�t�H���g�l����
					|| ' FROM (SELECT ' || colNames 
					|| ', S1.MEM_NO MEM_NO, S1.CARD_NO CARD_NO '
					|| ' FROM (' || detailSql || ') D1'												--���ו�
					|| ' CROSS JOIN (' || specifySql || ') S1'							--������A�f�J���g�ώ擾
					|| ' ORDER BY S1.MEM_NO)';											--�\�[�g�L�[�w��-MEM_NO
	
	
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
	detailSql := 'SELECT ' || colNames || ' FROM URI_DETAIL_SKY_ZAN M1 INNER JOIN '
					|| '(SELECT MAX(ZAN_NO) ZN, MAX(SKY_YM) YM, URI_NO UN FROM URI_DETAIL_SKY_ZAN WHERE '
					|| 'URI_NO IN (' || originUriNo || ') GROUP BY URI_NO) S1 '	--������ԍ�
					|| 'ON M1.URI_NO=S1.UN AND M1.ZAN_NO=ZN AND M1.SKY_YM=S1.YM ORDER BY URI_NO'; --�B�ꐫ
	
	sql_str := 'SELECT COUNT(*) FROM (' || detailSql || ')';
	
	--dbms_output.put_line(sql_str); --�e�X�g�p�ASQL�o��
	
	execute immediate sql_str into currentCnt;
	dbms_output.put_line(logTblName || '�e����̑������׌��� : ' || currentCnt);
	
	
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
					|| 'MEM_NO, CARD_NO, '
					|| colNames																	--�������f�[�^����
					|| ', '
					|| defaultVals	 															--�f�t�H���g�l����
					|| ' FROM (SELECT ' || colNames 
					|| ', S1.MEM_NO MEM_NO, S1.CARD_NO CARD_NO '
					|| ' FROM (' || detailSql || ') D1'												--���ו�
					|| ' CROSS JOIN (' || specifySql || ') S1'							--������A�f�J���g�ώ擾
					|| ' ORDER BY S1.MEM_NO)';											--�\�[�g�L�[�w��-MEM_NO
	
	
	--dbms_output.put_line(sql_str); --�e�X�g�p�ASQL�o��
	execute immediate sql_str;
	SELECT COUNT(*) INTO currentCnt FROM URI_DETAIL_SKY_ZAN;	
	dbms_output.put_line(logTblName || '�������{�㑍�����i�������ȊO�j : ' || currentCnt);
	
	--�������ǉ�	
	specifySql := 'SELECT ZAN_NO, URI_NO, MEM_NO, CARD_NO, ' || colNames || ' FROM URI_DETAIL_SKY_ZAN WHERE '
					|| 'MOD(URI_NO - ' || max_URI_NO || ', 10) =' || installmentIdx || ' ORDER BY URI_NO';	 --�������̂ݎ擾
	detailSql := 'SELECT IN_SKY_YM FROM (' || skyYMInstallment || ')';
	
	sql_str := 'INSERT /*APPEND*/ INTO URI_DETAIL_SKY_ZAN('				--���㖾�א����c��-URI_DETAIL_SKY_ZAN
					|| getColsWithComma(extendCols)		--INSERT�ΏۃR�����i���Ԏw��̂��߁A�������ځj
					|| ', '
					|| colNames										--INSERT�ΏۃR�����i���Ԏw��̂��߁A�������f�[�^���ځj
					|| ', '
					|| getColsWithComma(defaultCols)		--INSERT�ΏۃR�����i���Ԏw��̂��߁A�f�t�H���g�l���ځj
					|| ') '
					|| 'SELECT ZAN_NO, IN_SKY_YM, '						--ZAN_NO�ASKY_YM
					|| 'URI_NO, MEM_NO, CARD_NO, '
					|| colNames																	--�������f�[�^����
					|| ', '
					|| defaultVals	 															--�f�t�H���g�l����
					|| ' FROM (SELECT ' || colNames 
					|| ', D1.IN_SKY_YM IN_SKY_YM '
					|| ', S1.ZAN_NO ZAN_NO, S1.URI_NO URI_NO, S1.MEM_NO MEM_NO, S1.CARD_NO CARD_NO '
					|| ' FROM (' || detailSql || ') D1'												--���ו�
					|| ' CROSS JOIN (' || specifySql || ') S1)';							--�f�J���g�ώ擾
	
	
	--dbms_output.put_line(sql_str); --�e�X�g�p�ASQL�o��
	execute immediate sql_str;
	
	-- �����㌏��
	SELECT COUNT(*) INTO currentCnt FROM URI_DETAIL_SKY_ZAN;	
	dbms_output.put_line(logTblName || '�������{�㑍���� : ' || currentCnt);
	extendCnt := currentCnt - extendCnt; --����������ݒ肷��
	dbms_output.put_line(logTblName || '�������� : ' || extendCnt);
	---------------------------------------------------------
	
end extendUriDetailTables;
/
