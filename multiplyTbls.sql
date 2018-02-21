set serveroutput on

----------------------------------------------------------------------------------------------
-- �^�C�v�ƃt�@���N�V����
----------------------------------------------------------------------------------------------
create or replace type colArrays as varray(50) of varchar2(500);
/

create or replace function getTblCols(
	tableName in varchar, 					--�e�[�u����
	extendCols in colArrays,			--�����ΏۃR���������X�g
	defaultCols in colArrays				--�����l�ΏۃR���������X�g
)
RETURN varchar
is
	colsWithoutExcluded varchar(5000); --�������
	colName varchar(500); 	-- ��
	CURSOR colcursor IS SELECT COLUMN_NAME FROM ALL_TAB_COLUMNS WHERE TABLE_NAME=tableName;
begin	

	colsWithoutExcluded := ' ';
	
	dbms_output.put_line('�e�[�u���̗񖼎擾 : ' || tableName);
	
	-- �񖼎擾
	OPEN colcursor;
		LOOP
			FETCH colcursor INTO colName;
			EXIT WHEN colcursor%notfound;
			--�����ΏۃR�����r��
			FOR col IN 1..extendCols.COUNT LOOP
				IF (extendCols(col) = colName) THEN
					colName := ' ';
				END IF;
			END LOOP;
			--�����l�ΏۃR�����r��
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
	colList in colArrays			--�R���������X�g
)
RETURN varchar
is
	cols varchar(5000); --�������
begin	

	cols := ' ';
	--�R���}�A��
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
	inVal in varchar			--���͒l
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
-- �v���V�[�W��
----------------------------------------------------------------------------------------------
--�@�@�P���P�Ǝ�L�[�ł̔{�����ʃv���V�[�W��
----------------------------------------------------------------------------------------------
create or replace procedure doubleTables(
	tableName in varchar, 					-- �e�[�u����
	pk in varchar,								-- ��L�[
	startValue in number					-- �J�n�l�i��L�[�̊J�n�l���w�肷��A�J�n�l�̓e�[�u���̍ő�l��菬�����ꍇ�A�e�[�u���̍ő�l��p����j
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
	
	--sql_str := sql_str || ' WHERE rownum <= 1';  --�e�X�g�p�A�����i���Ă���
	
	--dbms_output.put_line(sql_str); --�e�X�g�p�ASQL�o��
	execute immediate sql_str;
	
	-- �������{�㑍����
	sql_str := 'SELECT COUNT(*) FROM ' || tableName;	
	execute immediate sql_str into currentCnt;
	dbms_output.put_line('�������{�㑍���� : ' || currentCnt);
	
end doubleTables;
/



----------------------------------------------------------------------------------------------
--�@�A�_��֘A�e�[�u���̔{��
--�@�l�ڋq�A�J�[�h�_��A�_��ڋq�֘A�A�_��c��
----------------------------------------------------------------------------------------------
create or replace procedure doubleSkyTables(
	sky_year in varchar, 					-- �����N�iYYYY�j
	sky_month in varchar,					-- �������iMM�j
	bill_create_date in varchar			-- �ŐV�������쐬�N�����iYYYYMMDD�j�i�ғ����O���j
)
is
	colNames varchar(5000); 		-- ��
	
	logTblName varchar(500);	--���O�o�͗p�e�[�u����
	
	sql_str varchar(20000); 		--SQL��
	specifySql varchar(20000); 		--�i��pSQL��
	
	extendCols colArrays;					-- �����ΏۃR���������X�g
	defaultCols colArrays;					-- �����l�ΏۃR���������X�g
	defaultVals varchar(5000);		-- �����l�Ώۏ����l
	
    currentCnt number;         		-- ����̑�����
    extendCnt number;         		-- �����ڕW����
	-- �l�ڋq�iKJN_CST�j�̑����L�[
    max_CST_NO number;          						-- �ڋq�ԍ��ő�l
	
	-- �J�[�h�_��iCARD_KYK�j�̑����L�[
    max_MEM_NO number;          						-- ����ԍ��ő�l
    max_CARD_TEIKEI_KYK_NO number;          	-- �J�[�h��g�_��ԍ��ő�l
    max_DOJI_MOSIKOMI_MEM_NO number;      -- �����\������ԍ��ő�l

	-- �_��ڋq�֘A�iKYK_CST_KANREN�j�̑����L�[
	max_KYK_CST_KANREN_NO number;			-- �_��ڋq�֘A�ԍ��ő�l
	max_MOSIKOMI_NO number;						-- �\���ԍ��ő�l
	max_CARD_NO number;								-- �J�[�h�ԍ��ő�l
	
	-- �_��c���iKYK_ZAN�j�̑����L�[�i�Ȃ��A��L�Ɋ܂܂��j

begin
	---------------------------------------------------------
	-- �l�ڋq�A�J�[�h�_��A�_��ڋq�֘A�Ŕ{���Ώێҍi��
	---------------------------------------------------------
	dbms_output.put_line('�����O�e�L�[�̍ő�l�擾' );
	-- �ڋq�ԍ��ő�l�擾
	SELECT MAX(CST_NO) INTO max_CST_NO FROM KJN_CST;	
	dbms_output.put_line('�ڋq�ԍ��ő�l�擾 : ' || max_CST_NO);
	
	-- ����ԍ��ő�l�擾
	SELECT MAX(MEM_NO) INTO max_MEM_NO FROM CARD_KYK;
	dbms_output.put_line('����ԍ��ő�l�擾 : ' || max_MEM_NO);
	-- �J�[�h��g�_��ԍ��ő�l�擾
	SELECT MAX(CARD_TEIKEI_KYK_NO) INTO max_CARD_TEIKEI_KYK_NO FROM CARD_KYK;
	dbms_output.put_line('�J�[�h��g�_��ԍ��ő�l�擾 : ' || max_CARD_TEIKEI_KYK_NO);
	-- �����\������ԍ��ő�l�擾
	SELECT MAX(DOJI_MOSIKOMI_MEM_NO) INTO max_DOJI_MOSIKOMI_MEM_NO FROM CARD_KYK;
	dbms_output.put_line('�����\������ԍ��ő�l�擾 : ' || max_DOJI_MOSIKOMI_MEM_NO);
	
	-- �_��ڋq�֘A�ԍ��ő�l�擾
	SELECT MAX(KYK_CST_KANREN_NO) INTO max_KYK_CST_KANREN_NO FROM KYK_CST_KANREN;
	dbms_output.put_line('�_��ڋq�֘A�ԍ��ő�l�擾 : ' || max_KYK_CST_KANREN_NO);
	-- �\���ԍ��ő�l�擾
	SELECT MAX(MOSIKOMI_NO) INTO max_MOSIKOMI_NO FROM KYK_CST_KANREN;
	dbms_output.put_line('�\���ԍ��ő�l�擾 : ' || max_MOSIKOMI_NO);
	-- �J�[�h�ԍ��ő�l�擾
	SELECT MAX(CARD_NO) INTO max_CARD_NO FROM KYK_CST_KANREN;
	dbms_output.put_line('�J�[�h�ԍ��ő�l�擾 : ' || max_CARD_NO);
	
	--�@�l�ڋq�̌����͏��Ȃ����߁A������L�[�ōi��
	specifySql := 'SELECT KJN_CST.CST_NO CST_NO, T1.KYK_CST_KANREN_NO KYK_CST_KANREN_NO, T1.MEM_NO MEM_NO '
					||	'FROM KJN_CST INNER JOIN '
					|| '(SELECT CST_NO, MAX(KYK_CST_KANREN.KYK_CST_KANREN_NO) KYK_CST_KANREN_NO, MAX(KYK_CST_KANREN.MEM_NO) MEM_NO '
					|| 'FROM KYK_CST_KANREN INNER JOIN CARD_KYK ON CARD_KYK.MEM_NO = KYK_CST_KANREN.MEM_NO '
					|| 'WHERE KYK_CST_KANREN.DELETE_SIGN=' || addQuota('0') || ' GROUP BY CST_NO) T1 '
					|| 'ON KJN_CST.CST_NO=T1.CST_NO '
					|| 'ORDER BY KJN_CST.CST_NO'; 
	
	-- �i���Ă���_��ڋq�֘A�̑�����
	sql_str := 'SELECT COUNT(*) FROM (' || specifySql || ')';
	execute immediate sql_str into currentCnt;
	dbms_output.put_line('�i���Ă���_��ڋq�֘A�̑����� : ' || currentCnt);
	
	-- �������{
	---------------------------------------------------------
	-- �l�ڋq-KJN_CST
	logTblName := '�e�[�u�����F�l�ڋq(KJN_CST)�@';

	-- �����O�l�ڋq������
	SELECT COUNT(*) INTO currentCnt FROM KJN_CST;	
	dbms_output.put_line(logTblName || '�������{�O������ : ' || currentCnt);
	extendCnt := currentCnt; --�����Ώی�����ݒ肷��
	
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
	
	sql_str := 'INSERT /*APPEND*/ INTO KJN_CST('				--�l�ڋq-KJN_CST
					|| getColsWithComma(extendCols)		--INSERT�ΏۃR�����i���Ԏw��̂��߁A�������ځj
					|| ', '
					|| colNames										--INSERT�ΏۃR�����i���Ԏw��̂��߁A�������f�[�^���ځj
					|| ', '
					|| getColsWithComma(defaultCols)		--INSERT�ΏۃR�����i���Ԏw��̂��߁A�f�t�H���g�l���ځj
					|| ') '
					
					|| 'SELECT TO_CHAR(' || max_CST_NO || '+rownum), '	--��������-CST_NO
					|| colNames													--�������f�[�^����
					|| ', '
					|| defaultVals	 											--�f�t�H���g�l����
					|| ' FROM (SELECT ' || colNames || ' FROM KJN_CST WHERE '					--�������f�[�^���ڎ擾
					|| ' KJN_CST.CST_NO IN (SELECT CST_NO FROM (' || specifySql || '))'		--�i�����f�[�^����擾
					|| ' ORDER BY KJN_CST.CST_NO)';															--�\�[�g�L�[�w��-CST_NO
	
	--sql_str := sql_str || ' WHERE rownum <= 10';  --�e�X�g�p�A�����i���Ă���
	
	dbms_output.put_line(sql_str); --�e�X�g�p�ASQL�o��
	execute immediate sql_str;
	
	-- �����l�ڋq������
	SELECT COUNT(*) INTO currentCnt FROM KJN_CST;	
	dbms_output.put_line(logTblName || '�������{�㑍���� : ' || currentCnt);
	extendCnt := currentCnt - extendCnt; --����������ݒ肷��
	dbms_output.put_line(logTblName || '�������� : ' || extendCnt);
	---------------------------------------------------------
	
	---------------------------------------------------------
	-- �J�[�h�_��-CARD_KYK
	logTblName := '�e�[�u�����F�J�[�h�_��(CARD_KYK)�@';

	-- �����O�l�ڋq������
	SELECT COUNT(*) INTO currentCnt FROM CARD_KYK;	
	dbms_output.put_line(logTblName || '�������{�O������ : ' || currentCnt);
	extendCnt := currentCnt; --�����Ώی�����ݒ肷��
	
	extendCols := colArrays('MEM_NO',
								'CARD_TEIKEI_KYK_NO',
								'DOJI_MOSIKOMI_MEM_NO');
	defaultCols := colArrays('KYK_EXPIRE_YM',                                                             ---�������Ȃ�Ȃ�ł�OK
										'CARD_KIRIKAE_YM',                                                          ---�󔒂ŗǂ�
										'CARD_NO_FAMILY_SAIHAKKO_GENERATOR_SEQ',             -- �󔒂ŗǂ�
										'KYK_MOSIKOMI_INTRODUCE_CARD_NO',                           ---�󔒂ŗǂ�
										'KYK_MOSIKOMI_INTRODUCE_USER_ID',                             -- �󔒂ŗǂ�
										'CARD_MOSIKOMI_INTRODUCE_KMTN_TKSK_NO',               ---�󔒂ŗǂ�
										'NENKAIHI_MENJO_KBN',                                                   -- �Ə��łȂ��l�Ƃ���
										'NENKAIHI_SKY_KIJUN_YEAR',                                            ---10%�𐿋��N�ő����B90%�͂Ȃ�ł�OK
										'NENKAIHI_SKY_KIJUN_MONTH',                                        -- 10%�𐿋��N�ő����B90%�͂Ȃ�ł�OK
										'LATEST_BILL_CREATE_DATE',                                            ---50%���ғ����O���Ƃ���B50%�͂Ȃ�ł�OK
										'BILL_STOP_SIGN',                                                            -- 5%���~�Ƃ���B95%�͏o�͑ΏۂƂ���
										'KASITUKE_DETAIL_STOP_SIGN',                                        ---5%���~�Ƃ���B95%�͏o�͑ΏۂƂ���
										'KZFR_TETUDUKI_ASSIGNED_KBN',                                    ---���ЂŐݒ�
										'KMTN_TKSK_KBN',                                                            ---���ЂŐݒ�
										'KMTN_TKSK_KYK_STS_KBN',                                             ---�󔒂ŗǂ�
										'KMTN_TKSK_USE_INFO_TOROKU_DATE',                           ---�󔒂ŗǂ�
										'HIGHRISK_KBN',                                                               ---���X�N��Ƃ���
										'HIGHRISK_TOROKU_DATE',                                               ---�󔒂ŗǂ�
										'HIGHRISK_JIDO_HANBETU_RESULT_KBN',                          -- �󔒂ŗǂ�
										'TANPO_CHOSHU_KBN',                                                     -- �S�ے�����
										'TANPO_CHOSHU_NY_KBN',                                                ---�S�ے�����
										'TANPO_CHOSHU_SIGN',                                                    ---�S�ے�����
										'GENERATED_TANPO_NO',                                                  ---�󔒂ŗǂ�
										'SHUNYU_INSI_DAI',                                                          ---�󔒂ŗǂ�
										'SHUNYU_INSI_DAI_CHOSHUSAKI_KBN',                            -- �S�ے�����
										'SHUNYU_INSI_DAI_CHOSHU_METHOD_KBN',                     ---�S�ے�����
										'JIMU_TESURYO',                                                                -- 0�Ƃ���
										'JIMU_TESURYO_CHOSHUSAKI_KBN',                                 -- ��������
										'JIMU_TESURYO_CHOSHU_METHOD_KBN',                           -- ��������
										'OTHER_HIYO_GAKU',                                                        -- 0�Ƃ���-
										'OTHER_UCHIWAKE_HIYO_URI_GAKU1',                             -- 0�Ƃ���-
										'OTHER_UCHIWAKE_HIYO_URI_GAKU2',                             -- 0�Ƃ���-
										'OTHER_UCHIWAKE_HIYO_URI_GAKU3',                             -- 0�Ƃ���-
										'OTHER_UCHIWAKE_HIYO_URI_GAKU4',                             -- 0�Ƃ���-
										'OTHER_UCHIWAKE_HIYO_URI_GAKU5',                             -- 0�Ƃ���-
										'OTHER_UCHIWAKE_HIYO_URI_GAKU6',                             -- 0�Ƃ���-
										'KYK_DAKKAI_DATE',                                                         -- �󔒂ŗǂ�-
										'KYK_SHUSI_DATE',                                                            -- �󔒂ŗǂ�-
										'KYK_SHUSI_HENSAI_STS_KBN',                                        ---�󔒂ŗǂ�
										'KYK_SHUSI_KANSAI_CHECK_DATE',                                   -- �󔒂ŗǂ�-
										'KYK_DELETE_YOTEI_DATE',                                               ---�󔒂ŗǂ�
										'KIRIKAE_MAE_CARD_TEIKEI_KYK_NO',                              ---�󔒂ŗǂ�
										'DIVIDE_NO',                                                                     ---�v���Z�X���ɂ���Đݒ�
										'DELETE_SIGN',                                                                 -- �����l-
										'DELETE_DATE',                                                                  -- �����l-
										'INSERT_USER_ID',                                                            ---�����l
										'INSERT_DATE_TIME',                                                        -- �����l-
										'UPDATE_USER_ID',                                                            -- �����l-
										'UPDATE_DATE_TIME',                                                        ---�����l
										'VERSION');                                                                       ---�����l
	defaultVals := addQuota('202305') || ', '	            	                   -- KYK_EXPIRE_YM                                                             ---�������Ȃ�Ȃ�ł�OK
						|| addQuota(' ') || ', '			         		                   -- CARD_KIRIKAE_YM                                                          ---�󔒂ŗǂ�
						|| addQuota(' ') || ', '			         		                   -- CARD_NO_FAMILY_SAIHAKKO_GENERATOR_SEQ             -- �󔒂ŗǂ�
						|| addQuota(' ') || ', '			         		                   -- KYK_MOSIKOMI_INTRODUCE_CARD_NO                           ---�󔒂ŗǂ�
						|| addQuota(' ') || ', '			         		                   -- KYK_MOSIKOMI_INTRODUCE_USER_ID                             -- �󔒂ŗǂ�
						|| addQuota(' ') || ', '			         		                   -- CARD_MOSIKOMI_INTRODUCE_KMTN_TKSK_NO               ---�󔒂ŗǂ�
						|| addQuota('0') || ', '			         		                   -- NENKAIHI_MENJO_KBN                                                   -- �Ə��łȂ��l�Ƃ���
						|| '(CASE WHEN MOD(rownum,10) = 0 THEN ' || addQuota(sky_year) || ' ELSE ' || addQuota('2018') || ' END), '
																									   -- NENKAIHI_SKY_KIJUN_YEAR                                            ---10%�𐿋��N�ő����B90%�͂Ȃ�ł�OK
						|| '(CASE WHEN MOD(rownum,10) = 0 THEN ' || addQuota(sky_month) || ' ELSE ' || addQuota('01') || ' END), '
																									   -- NENKAIHI_SKY_KIJUN_MONTH                                        -- 10%�𐿋��N�ő����B90%�͂Ȃ�ł�OK
						|| '(CASE WHEN MOD(rownum,2) = 0 THEN ' || addQuota(bill_create_date) || ' ELSE ' || addQuota('20170101') || ' END), '
																									   -- LATEST_BILL_CREATE_DATE                                            ---50%���ғ����O���Ƃ���B50%�͂Ȃ�ł�OK
						|| addQuota('0') || ', '			         		                    -- BILL_STOP_SIGN                                                            -- 5%���~�Ƃ���B95%�͏o�͑ΏۂƂ���ˌŒ�l
						|| addQuota('0') || ', '			         		                    -- KASITUKE_DETAIL_STOP_SIGN                                        ---5%���~�Ƃ���B95%�͏o�͑ΏۂƂ���ˌŒ�l
						|| addQuota('0') || ', '			         		                    -- KZFR_TETUDUKI_ASSIGNED_KBN                                    ---���ЂŐݒ�
						|| addQuota('0') || ', '			         		                    -- KMTN_TKSK_KBN                                                            ---���ЂŐݒ�
						|| addQuota(' ') || ', '	   		         		                    -- KMTN_TKSK_KYK_STS_KBN                                             ---�󔒂ŗǂ�
						|| addQuota('        ') || ', '		         		                    -- KMTN_TKSK_USE_INFO_TOROKU_DATE                           ---�󔒂ŗǂ�
						|| addQuota('0') || ', '			         		                    -- HIGHRISK_KBN                                                               ---���X�N��Ƃ���
						|| addQuota('        ') || ', '		         		                    -- HIGHRISK_TOROKU_DATE                                               ---�󔒂ŗǂ�
						|| addQuota('   ') || ', '			         		                    -- HIGHRISK_JIDO_HANBETU_RESULT_KBN                          -- �󔒂ŗǂ�
						|| addQuota('0') || ', '			         		                    -- TANPO_CHOSHU_KBN                                                     -- �S�ے�����
						|| addQuota('0') || ', '			         		                    -- TANPO_CHOSHU_NY_KBN                                                ---�S�ے�����
						|| addQuota('0') || ', '			         		                    -- TANPO_CHOSHU_SIGN                                                    ---�S�ے�����
						|| addQuota('    ') || ', '			         		                    -- GENERATED_TANPO_NO                                                  ---�󔒂ŗǂ�
						|| '0, '			         		         						            -- SHUNYU_INSI_DAI                                                          ---�󔒂ŗǂ�
						|| addQuota('0') || ', '			         		                    -- SHUNYU_INSI_DAI_CHOSHUSAKI_KBN                            -- �S�ے�����
						|| addQuota('0') || ', '			         		                    -- SHUNYU_INSI_DAI_CHOSHU_METHOD_KBN                     ---�S�ے�����
						|| '0, '									         		                    -- JIMU_TESURYO                                                                -- 0�Ƃ���
						|| addQuota('0') || ', '			         		                    -- JIMU_TESURYO_CHOSHUSAKI_KBN                                 -- ��������
						|| addQuota('0') || ', '			         		                    -- JIMU_TESURYO_CHOSHU_METHOD_KBN                           -- ��������
						|| '0, '									         		                    -- OTHER_HIYO_GAKU                                                        -- 0�Ƃ���-
						|| '0, '									         		                    -- OTHER_UCHIWAKE_HIYO_URI_GAKU1                             -- 0�Ƃ���-
						|| '0, '									         		                    -- OTHER_UCHIWAKE_HIYO_URI_GAKU2                             -- 0�Ƃ���-
						|| '0, '									         		                    -- OTHER_UCHIWAKE_HIYO_URI_GAKU3                             -- 0�Ƃ���-
						|| '0, '									         		                    -- OTHER_UCHIWAKE_HIYO_URI_GAKU4                             -- 0�Ƃ���-
						|| '0, '									         		                    -- OTHER_UCHIWAKE_HIYO_URI_GAKU5                             -- 0�Ƃ���-
						|| '0, '									         		                    -- OTHER_UCHIWAKE_HIYO_URI_GAKU6                             -- 0�Ƃ���-
						|| addQuota('        ') || ', '			       		                    -- KYK_DAKKAI_DATE                                                         -- �󔒂ŗǂ�-
						|| addQuota('        ') || ', '			       		                    -- KYK_SHUSI_DATE                                                            -- �󔒂ŗǂ�-
						|| addQuota('  ') || ', '			         		                    -- KYK_SHUSI_HENSAI_STS_KBN                                        ---�󔒂ŗǂ�
						|| addQuota('        ') || ', '			       		                    -- KYK_SHUSI_KANSAI_CHECK_DATE                                   -- �󔒂ŗǂ�-
						|| addQuota('        ') || ', '			       		                    -- KYK_DELETE_YOTEI_DATE                                               ---�󔒂ŗǂ�
						|| addQuota('            ') || ', '			   		                    -- KIRIKAE_MAE_CARD_TEIKEI_KYK_NO                              ---�󔒂ŗǂ�
						|| addQuota('1') || ', '			         		                    -- DIVIDE_NO                                                                     ---�v���Z�X���ɂ���Đݒ�
						|| addQuota('0') || ', '			         		                    -- DELETE_SIGN                                                                 -- �����l-
						|| addQuota('        ') || ', '		         		                    -- DELETE_DATE                                                                  -- �����l-
						|| addQuota(' ')	 || ', '												--INSERT_USER_ID
						|| 'sysdate, '																--INSERT_DATE_TIME
						|| addQuota(' ')	 || ', '												--UPDATE_USER_ID
						|| 'sysdate, 1'; 														--UPDATE_DATE_TIME, VERSION
	
	colNames := getTblCols('CARD_KYK', extendCols, defaultCols);
	
	sql_str := 'INSERT /*APPEND*/ INTO CARD_KYK('				--�J�[�h�_��-CARD_KYK
					|| getColsWithComma(extendCols)		--INSERT�ΏۃR�����i���Ԏw��̂��߁A�������ځj
					|| ', '
					|| colNames										--INSERT�ΏۃR�����i���Ԏw��̂��߁A�������f�[�^���ځj
					|| ', '
					|| getColsWithComma(defaultCols)	 	--INSERT�ΏۃR�����i���Ԏw��̂��߁A�f�t�H���g�l���ځj
					|| ') '
	
					|| 'SELECT TO_CHAR(' || max_MEM_NO || '+rownum), '							--��������-MEM_NO
					|| 'TO_CHAR(' || max_CARD_TEIKEI_KYK_NO || '+rownum), '						--��������-CARD_TEIKEI_KYK_NO
					|| 'TO_CHAR(' || max_DOJI_MOSIKOMI_MEM_NO || '+rownum), '					--��������-DOJI_MOSIKOMI_MEM_NO
					|| colNames																			--�������f�[�^����
					|| ', '
					|| defaultVals 																		--�f�t�H���g�l����
					|| ' FROM (SELECT ' || colNames || ' FROM CARD_KYK INNER JOIN '		--�������f�[�^���ڎ擾
					|| ' (' || specifySql || ') T2 ON CARD_KYK.MEM_NO = T2.MEM_NO '		--�i�����f�[�^����擾
					|| ' ORDER BY T2.CST_NO)';																--�\�[�g�L�[�w��-CST_NO�̏���葝���i�֘A����ۂ��߁j
	
	--sql_str := sql_str || ' WHERE rownum <= 20';  --�e�X�g�p�A�����i���Ă���
	
	dbms_output.put_line(sql_str); --�e�X�g�p�ASQL�o��
	execute immediate sql_str;
	
	-- �����J�[�h�_�񑍌���
	SELECT COUNT(*) INTO currentCnt FROM CARD_KYK;	
	dbms_output.put_line(logTblName || '�������{�㑍���� : ' || currentCnt);
	
	extendCnt := currentCnt - extendCnt; --����������ݒ肷��
	dbms_output.put_line(logTblName || '�������� : ' || extendCnt);
		
	
	-- �����N�ő����̑�����
	sql_str := 'SELECT COUNT(*) FROM CARD_KYK WHERE LATEST_BILL_CREATE_DATE = ' 
				|| addQuota(bill_create_date) || ' AND MEM_NO >' || addQuota(max_MEM_NO);
	execute immediate sql_str into currentCnt;
	dbms_output.put_line('�����N�ő����̑����� : ' || currentCnt);
		
	
	-- �ғ����O���̑�����
	sql_str := 'SELECT COUNT(*) FROM CARD_KYK WHERE NENKAIHI_SKY_KIJUN_YEAR = ' 
				|| addQuota(sky_year) || ' AND NENKAIHI_SKY_KIJUN_MONTH = '
				|| addQuota(sky_month) || ' AND MEM_NO >' || addQuota(max_MEM_NO);
	execute immediate sql_str into currentCnt;
	dbms_output.put_line('�ғ����O���̑����� : ' || currentCnt);
	---------------------------------------------------------
	
	-- �������{�㑍����
	sql_str := 'SELECT COUNT(*) FROM (' || specifySql || ')';	
	execute immediate sql_str into currentCnt;
	dbms_output.put_line('�������{�㑍���� : ' || currentCnt);
	
end doubleSkyTables;
/
 