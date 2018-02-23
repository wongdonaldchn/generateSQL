set serveroutput on

----------------------------------------------------------------------------------------------
-- �v���V�[�W��
----------------------------------------------------------------------------------------------
--�@�A�_��֘A�e�[�u���̔{��
--�@�l�ڋq�A�J�[�h�_��A�_��ڋq�֘A�A�_��c��
----------------------------------------------------------------------------------------------
create or replace procedure doubleSkyTables(
	sky_year in varchar, 					-- �����N�iYYYY�j
	sky_month in varchar,					-- �������iMM�j
	bill_create_date in varchar,			-- �ŐV�������쐬�N�����iYYYYMMDD�j�i�ғ����O���j
	toExtendCnt in number					-- �����w�茏���i���f�[�^�̌������傫���̏ꍇ�͌��f�[�^�ɂ�葝���j
)
is
	colNames varchar(5000); 		-- ��
	
	logTblName varchar(500);	--���O�o�͗p�e�[�u����
	
	sql_str varchar(20000); 		--SQL��
	specifySql varchar(20000); 		--�i��pSQL��
	
	extendCols colArrays;					-- �����ΏۃR���������X�g
	defaultCols colArrays;					-- �����l�ΏۃR���������X�g
	defaultVals varchar(5000);		-- �����l�Ώۏ����l
	
    extendTargetCnt number;         		-- �����ڕW����
    currentCnt number;         				-- ����̑�����
    extendCnt number;         				-- ��������
	
    max_CST_NO number;          						-- �ڋq�ԍ��ő�l
	max_MEM_NO number;          						-- ����ԍ��ő�l
	max_CARD_NO number;								-- �J�[�h�ԍ��ő�l
	
    max_KEY1 number;          	-- �����p�L�[�P
    max_KEY2 number;      		-- �����p�L�[�Q
    max_KEY3 number;      		-- �����p�L�[�R


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
	
	-- �J�[�h�ԍ��ő�l�擾
	SELECT MAX(CARD_NO) INTO max_CARD_NO FROM CARD;
	dbms_output.put_line('�J�[�h�ԍ��ő�l�擾 : ' || max_CARD_NO);
	
	
	--�@�O�̃L�[�ł��ꂼ��B��ōi��
	specifySql := 'SELECT MAX(CST_NO) CST_NO, MAX(KYK_CST_KANREN_NO) KYK_CST_KANREN_NO, MEM_NO '
					||	'FROM (SELECT CST_NO, MAX(KYK_CST_KANREN_NO) KYK_CST_KANREN_NO, MAX(MEM_NO) MEM_NO '
					|| 'FROM KYK_CST_KANREN '
					|| 'WHERE KYK_CST_KANREN.DELETE_SIGN=' || addQuota('0') || ' GROUP BY CST_NO) '
					|| 'GROUP BY MEM_NO '
					|| 'ORDER BY MEM_NO';
	
	-- �i���Ă���_��ڋq�֘A�̑�����
	sql_str := 'SELECT COUNT(*) FROM (' || specifySql || ')';
	execute immediate sql_str into currentCnt;
	dbms_output.put_line('�i���Ă���_��ڋq�֘A�̑����� : ' || currentCnt);
	
	-- �����ڕW������ݒ肷��
	sql_str := 'SELECT COUNT(DISTINCT MEM_NO) FROM (' || specifySql || ')';
	extendTargetCnt := currentCnt;
	if (extendTargetCnt > toExtendCnt) then
		extendTargetCnt := toExtendCnt;
	end if;
	dbms_output.put_line('�����ڕW���� : ' || extendTargetCnt);
	
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
					|| ' FROM (SELECT ' || colNames || ' FROM KJN_CST '					--�������f�[�^���ڎ擾
					|| ' INNER JOIN (' || specifySql || ') S1'		--�i�����f�[�^����擾
					|| ' ON S1.CST_NO = KJN_CST.CST_NO'
					|| ' ORDER BY S1.MEM_NO)';															--�\�[�g�L�[�w��-MEM_NO
	
	sql_str := sql_str || ' WHERE rownum <= ' || extendTargetCnt;  --�����w��i�������͍ő匏���j
	
	--dbms_output.put_line(sql_str); --�e�X�g�p�ASQL�o��
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

	-- �����O������
	SELECT COUNT(*) INTO currentCnt FROM CARD_KYK;	
	dbms_output.put_line(logTblName || '�������{�O������ : ' || currentCnt);
	extendCnt := currentCnt; --�����Ώی�����ݒ肷��
	
	-- �J�[�h��g�_��ԍ��ő�l�擾
	SELECT MAX(CARD_TEIKEI_KYK_NO) INTO max_KEY1 FROM CARD_KYK;
	dbms_output.put_line(logTblName || '�J�[�h��g�_��ԍ��ő�l�擾 : ' || max_KEY1);
	-- �����\������ԍ��ő�l�擾
	SELECT MAX(DOJI_MOSIKOMI_MEM_NO) INTO max_KEY2 FROM CARD_KYK;
	dbms_output.put_line(logTblName || '�����\������ԍ��ő�l�擾 : ' || max_KEY2);
	
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
					|| 'TO_CHAR(' || max_KEY1 || '+rownum), '						--��������-CARD_TEIKEI_KYK_NO
					|| 'TO_CHAR(' || max_KEY2 || '+rownum), '					--��������-DOJI_MOSIKOMI_MEM_NO
					|| colNames																			--�������f�[�^����
					|| ', '
					|| defaultVals 																		--�f�t�H���g�l����
					|| ' FROM (SELECT ' || colNames || ' FROM CARD_KYK WHERE '		--�������f�[�^���ڎ擾
					|| ' CARD_KYK.MEM_NO IN (SELECT MEM_NO FROM (' || specifySql || '))'		--�i�����f�[�^����擾�FDISTINCT�ς݂̂��߁A�či��s�v
					|| ' ORDER BY CARD_KYK.MEM_NO)';															--�\�[�g�L�[�w��-MEM_NO
	
	sql_str := sql_str || ' WHERE rownum <= ' || extendTargetCnt;  --�����w��i�������͍ő匏���j
	
	--dbms_output.put_line(sql_str); --�e�X�g�p�ASQL�o��
	execute immediate sql_str;
	
	-- �����㑍����
	SELECT COUNT(*) INTO currentCnt FROM CARD_KYK;	
	dbms_output.put_line(logTblName || '�������{�㑍���� : ' || currentCnt);
	
	extendCnt := currentCnt - extendCnt; --����������ݒ肷��
	dbms_output.put_line(logTblName || '�������� : ' || extendCnt);
		
	
	-- �ғ����O���̑�����
	sql_str := 'SELECT COUNT(*) FROM CARD_KYK WHERE LATEST_BILL_CREATE_DATE = ' 
				|| addQuota(bill_create_date) || ' AND MEM_NO >' || addQuota(max_MEM_NO);
	execute immediate sql_str into currentCnt;
	dbms_output.put_line(logTblName || '�ғ����O���ő����̑����� : ' || currentCnt);
		
	
	-- �����N�ő����̑�����
	sql_str := 'SELECT COUNT(*) FROM CARD_KYK WHERE NENKAIHI_SKY_KIJUN_YEAR = ' 
				|| addQuota(sky_year) || ' AND NENKAIHI_SKY_KIJUN_MONTH = '
				|| addQuota(sky_month) || ' AND MEM_NO >' || addQuota(max_MEM_NO);
	execute immediate sql_str into currentCnt;
	dbms_output.put_line(logTblName || '�����N�ő����̑����� : ' || currentCnt);
	---------------------------------------------------------
	
	
	---------------------------------------------------------
	-- �J�[�h�_�񗘗��敪-CARD_KYK_RIRITU_KBN
	logTblName := '�e�[�u�����F�J�[�h�_�񗘗��敪(CARD_KYK_RIRITU_KBN)�@';

	-- �����O�l�ڋq������
	SELECT COUNT(*) INTO currentCnt FROM CARD_KYK_RIRITU_KBN;	
	dbms_output.put_line(logTblName || '�������{�O������ : ' || currentCnt);
	extendCnt := currentCnt; --�����Ώی�����ݒ肷��
	
	extendCols := colArrays('MEM_NO');
	defaultCols := colArrays('SP_CS_SIKIBETU_KBN',                                                             ---�V���b�s���O�L���b�V���O���ʋ敪�F�u1:�V���b�s���O�v�Œ�
										'APPLY_END_URI_SIME_DATE',                                                    ---�K�p�I��������N�����F�󔒂ŗǂ�
										'RIRITU',          																			 -- �����FDECIMAL�󔒂ŗǂ�
										'DELETE_SIGN',                                                                 -- �����l-
										'DELETE_DATE',                                                                  -- �����l-
										'INSERT_USER_ID',                                                            ---�����l
										'INSERT_DATE_TIME',                                                        -- �����l-
										'UPDATE_USER_ID',                                                            -- �����l-
										'UPDATE_DATE_TIME');                                                      ---�����l
	defaultVals := addQuota('1') || ', '	            					                   -- SP_CS_SIKIBETU_KBN        ---�V���b�s���O�L���b�V���O���ʋ敪�F�u1:�V���b�s���O�v�Œ�
						|| addQuota('        ') || ', '			         		                   -- APPLY_END_URI_SIME_DATE   -�K�p�I��������N�����F�󔒂ŗǂ�
						|| '0, '			         		                   								-- RIRITU             �����FDECIMAL�󔒂ŗǂ�
						|| addQuota('0') || ', '			         		                    -- DELETE_SIGN                                                                 -- �����l-
						|| addQuota('        ') || ', '		         		                    -- DELETE_DATE                                                                  -- �����l-
						|| addQuota(' ')	 || ', '												--INSERT_USER_ID
						|| 'sysdate, '																--INSERT_DATE_TIME
						|| addQuota(' ')	 || ', '												--UPDATE_USER_ID
						|| 'sysdate'; 																--UPDATE_DATE_TIME
	
	colNames := getTblCols('CARD_KYK_RIRITU_KBN', extendCols, defaultCols);
	
	sql_str := 'INSERT /*APPEND*/ INTO CARD_KYK_RIRITU_KBN('				--�J�[�h�_�񗘗��敪-CARD_KYK_RIRITU_KBN
					|| getColsWithComma(extendCols)		--INSERT�ΏۃR�����i���Ԏw��̂��߁A�������ځj
					|| ', '
					|| colNames										--INSERT�ΏۃR�����i���Ԏw��̂��߁A�������f�[�^���ځj
					|| ', '
					|| getColsWithComma(defaultCols)	 	--INSERT�ΏۃR�����i���Ԏw��̂��߁A�f�t�H���g�l���ځj
					|| ') '
	
					|| 'SELECT TO_CHAR(' || max_MEM_NO || '+rownum), '							--��������-MEM_NO
					|| colNames																			--�������f�[�^����
					|| ', '
					|| defaultVals 																		--�f�t�H���g�l����
					|| ' FROM (SELECT ' || colNames || ' FROM CARD_KYK_RIRITU_KBN M1 INNER JOIN '		--�������f�[�^���ڎ擾
					|| '(SELECT MEM_NO PK1, '																			--������L�[���i��
					|| 'MAX(SP_CS_SIKIBETU_KBN) PK2, '															--������L�[���i��
					|| 'MAX(APPLY_START_URI_SIME_DATE) PK3 '												--������L�[���i��
					|| 'FROM CARD_KYK_RIRITU_KBN '
					|| 'WHERE CARD_KYK_RIRITU_KBN.MEM_NO IN (SELECT MEM_NO FROM (' || specifySql || ')) '		--�i�����f�[�^����擾
					|| 'GROUP BY MEM_NO) S1 '	
					|| 'ON M1.MEM_NO = S1.PK1 '																		--������L�[���i��
					|| 'AND M1.SP_CS_SIKIBETU_KBN = S1.PK2 '													--������L�[���i��
					|| 'AND M1.APPLY_START_URI_SIME_DATE = S1.PK3 '									--������L�[���i��
					|| 'ORDER BY M1.MEM_NO)';																			--�\�[�g�L�[�w��-MEM_NO
	
	sql_str := sql_str || ' WHERE rownum <= ' || extendTargetCnt;  --�����w��i�������͍ő匏���j
	
	--dbms_output.put_line(sql_str); --�e�X�g�p�ASQL�o��
	execute immediate sql_str;
	
	-- �����㑍����
	SELECT COUNT(*) INTO currentCnt FROM CARD_KYK_RIRITU_KBN;	
	dbms_output.put_line(logTblName || '�������{�㑍���� : ' || currentCnt);
	
	extendCnt := currentCnt - extendCnt; --����������ݒ肷��
	dbms_output.put_line(logTblName || '�������� : ' || extendCnt);

	---------------------------------------------------------
	
	---------------------------------------------------------
	-- �J�[�h�_��x���R�[�X-CARD_KYK_SHR_COURSE
	logTblName := '�e�[�u�����F�J�[�h�_��x���R�[�X(CARD_KYK_SHR_COURSE)�@';

	-- �����O�l�ڋq������
	SELECT COUNT(*) INTO currentCnt FROM CARD_KYK_SHR_COURSE;	
	dbms_output.put_line(logTblName || '�������{�O������ : ' || currentCnt);
	extendCnt := currentCnt; --�����Ώی�����ݒ肷��
	
	extendCols := colArrays('MEM_NO');
	defaultCols := colArrays('APPLY_END_SKY_SIME_DATE',                                                    ---�K�p�I���������N�����F�󔒂ŗǂ�
										'DELETE_SIGN',                                                                 -- �����l-
										'DELETE_DATE',                                                                  -- �����l-
										'INSERT_USER_ID',                                                            ---�����l
										'INSERT_DATE_TIME',                                                        -- �����l-
										'UPDATE_USER_ID',                                                            -- �����l-
										'UPDATE_DATE_TIME');                                                      ---�����l
	defaultVals := addQuota('        ') || ', '			         		                   -- APPLY_END_SKY_SIME_DATE   -�K�p�I���������N�����F�󔒂ŗǂ�
						|| addQuota('0') || ', '			         		                    -- DELETE_SIGN                                                                 -- �����l-
						|| addQuota('        ') || ', '		         		                    -- DELETE_DATE                                                                  -- �����l-
						|| addQuota(' ')	 || ', '												--INSERT_USER_ID
						|| 'sysdate, '																--INSERT_DATE_TIME
						|| addQuota(' ')	 || ', '												--UPDATE_USER_ID
						|| 'sysdate'; 																--UPDATE_DATE_TIME
	
	colNames := getTblCols('CARD_KYK_SHR_COURSE', extendCols, defaultCols);
	
	sql_str := 'INSERT /*APPEND*/ INTO CARD_KYK_SHR_COURSE('				--�J�[�h�_�񗘗��敪-CARD_KYK_SHR_COURSE
					|| getColsWithComma(extendCols)		--INSERT�ΏۃR�����i���Ԏw��̂��߁A�������ځj
					|| ', '
					|| colNames										--INSERT�ΏۃR�����i���Ԏw��̂��߁A�������f�[�^���ځj
					|| ', '
					|| getColsWithComma(defaultCols)	 	--INSERT�ΏۃR�����i���Ԏw��̂��߁A�f�t�H���g�l���ځj
					|| ') '
	
					|| 'SELECT TO_CHAR(' || max_MEM_NO || '+rownum), '							--��������-MEM_NO
					|| colNames																			--�������f�[�^����
					|| ', '
					|| defaultVals 																		--�f�t�H���g�l����
					|| ' FROM (SELECT ' || colNames || ' FROM CARD_KYK_SHR_COURSE M1 INNER JOIN '		--�������f�[�^���ڎ擾
					|| '(SELECT MEM_NO PK1, '													--������L�[���i��
					|| 'MAX(APPLY_START_SKY_SIME_DATE) PK2 '						--������L�[���i��
					|| 'FROM CARD_KYK_SHR_COURSE '
					|| 'WHERE CARD_KYK_SHR_COURSE.MEM_NO IN (SELECT MEM_NO FROM (' || specifySql || ')) '		--�i�����f�[�^����擾
					|| 'GROUP BY MEM_NO) S1 '	
					|| 'ON M1.MEM_NO = S1.PK1 '												--������L�[���i��
					|| 'AND M1.APPLY_START_SKY_SIME_DATE = S1.PK2 '			--������L�[���i��
					|| 'ORDER BY M1.MEM_NO)';													--�\�[�g�L�[�w��-MEM_NO
	
	sql_str := sql_str || ' WHERE rownum <= ' || extendTargetCnt;  --�����w��i�������͍ő匏���j
	
	--dbms_output.put_line(sql_str); --�e�X�g�p�ASQL�o��
	execute immediate sql_str;
	
	-- �����㑍����
	SELECT COUNT(*) INTO currentCnt FROM CARD_KYK_SHR_COURSE;	
	dbms_output.put_line(logTblName || '�������{�㑍���� : ' || currentCnt);
	
	extendCnt := currentCnt - extendCnt; --����������ݒ肷��
	dbms_output.put_line(logTblName || '�������� : ' || extendCnt);

	---------------------------------------------------------
	
	
	---------------------------------------------------------
	-- �J�[�h���WEB�o�^��񗚗�-CARD_MEM_WEB_TOROKU_INFO_HISTORY
	logTblName := '�e�[�u�����F�J�[�h���WEB�o�^��񗚗�(CARD_MEM_WEB_TOROKU_INFO_HISTORY)�@';

	-- �����O�l�ڋq������
	SELECT COUNT(*) INTO currentCnt FROM CARD_MEM_WEB_TOROKU_INFO_HISTORY;	
	dbms_output.put_line(logTblName || '�������{�O������ : ' || currentCnt);
	extendCnt := currentCnt; --�����Ώی�����ݒ肷��
	
	extendCols := colArrays('MEM_NO');
	defaultCols := colArrays('WEB_GYOMU_SEQ',                                                    ---WEB�Ɩ��A�ԁF����ԍ��AWEB�Ɩ��敪����00001����̘A�ԁB
										'DELETE_SIGN',                                                                 -- �����l-
										'DELETE_DATE',                                                                  -- �����l-
										'INSERT_USER_ID',                                                            ---�����l
										'INSERT_DATE_TIME',                                                        -- �����l-
										'UPDATE_USER_ID',                                                            -- �����l-
										'UPDATE_DATE_TIME');                                                      ---�����l
	defaultVals := '1, '			         		                   								-- WEB_GYOMU_SEQ   WEB�Ɩ��A�ԁF����ԍ��AWEB�Ɩ��敪����00001����̘A�ԁB
						|| addQuota('0') || ', '			         		                    -- DELETE_SIGN                                                                 -- �����l-
						|| addQuota('        ') || ', '		         		                    -- DELETE_DATE                                                                  -- �����l-
						|| addQuota(' ')	 || ', '												--INSERT_USER_ID
						|| 'sysdate, '																--INSERT_DATE_TIME
						|| addQuota(' ')	 || ', '												--UPDATE_USER_ID
						|| 'sysdate'; 																--UPDATE_DATE_TIME
	
	colNames := getTblCols('CARD_MEM_WEB_TOROKU_INFO_HISTORY', extendCols, defaultCols);
	
	sql_str := 'INSERT /*APPEND*/ INTO CARD_MEM_WEB_TOROKU_INFO_HISTORY('				--�J�[�h���WEB�o�^��񗚗�-CARD_MEM_WEB_TOROKU_INFO_HISTORY
					|| getColsWithComma(extendCols)		--INSERT�ΏۃR�����i���Ԏw��̂��߁A�������ځj
					|| ', '
					|| colNames										--INSERT�ΏۃR�����i���Ԏw��̂��߁A�������f�[�^���ځj
					|| ', '
					|| getColsWithComma(defaultCols)	 	--INSERT�ΏۃR�����i���Ԏw��̂��߁A�f�t�H���g�l���ځj
					|| ') '
	
					|| 'SELECT TO_CHAR(' || max_MEM_NO || '+rownum), '							--��������-MEM_NO
					|| colNames																			--�������f�[�^����
					|| ', '
					|| defaultVals 																		--�f�t�H���g�l����
					|| ' FROM (SELECT ' || colNames || ' FROM CARD_MEM_WEB_TOROKU_INFO_HISTORY M1 INNER JOIN '		--�������f�[�^���ڎ擾
					|| '(SELECT MEM_NO PK1, '													--������L�[���i��
					|| 'MAX(WEB_GYOMU_KBN) PK2, '						--������L�[���i��
					|| 'MAX(WEB_GYOMU_SEQ) PK3 '						--������L�[���i��
					|| 'FROM CARD_MEM_WEB_TOROKU_INFO_HISTORY '
					|| 'WHERE CARD_MEM_WEB_TOROKU_INFO_HISTORY.MEM_NO IN (SELECT MEM_NO FROM (' || specifySql || ')) '		--�i�����f�[�^����擾
					|| 'GROUP BY MEM_NO) S1 '	
					|| 'ON M1.MEM_NO = S1.PK1 '												--������L�[���i��
					|| 'AND M1.WEB_GYOMU_KBN = S1.PK2 '			--������L�[���i��
					|| 'AND M1.WEB_GYOMU_SEQ = S1.PK3 '			--������L�[���i��
					|| 'ORDER BY M1.MEM_NO)';													--�\�[�g�L�[�w��-MEM_NO
	
	sql_str := sql_str || ' WHERE rownum <= ' || extendTargetCnt;  --�����w��i�������͍ő匏���j
	
	--dbms_output.put_line(sql_str); --�e�X�g�p�ASQL�o��
	execute immediate sql_str;
	
	-- �����㑍����
	SELECT COUNT(*) INTO currentCnt FROM CARD_MEM_WEB_TOROKU_INFO_HISTORY;	
	dbms_output.put_line(logTblName || '�������{�㑍���� : ' || currentCnt);
	
	extendCnt := currentCnt - extendCnt; --����������ݒ肷��
	dbms_output.put_line(logTblName || '�������� : ' || extendCnt);

	---------------------------------------------------------
	
	
	---------------------------------------------------------
	-- �J�[�h-CARD
	logTblName := '�e�[�u�����F�J�[�h(CARD)�@';

	-- �����O������
	SELECT COUNT(*) INTO currentCnt FROM CARD;	
	dbms_output.put_line(logTblName || '�������{�O������ : ' || currentCnt);
	extendCnt := currentCnt; --�����Ώی�����ݒ肷��
	
	extendCols := colArrays('CARD_NO',
										'MEM_NO');
	defaultCols := colArrays('DELETE_SIGN',                                                                 -- �����l-
										'DELETE_DATE',                                                                  -- �����l-
										'INSERT_USER_ID',                                                            ---�����l
										'INSERT_DATE_TIME',                                                        -- �����l-
										'UPDATE_USER_ID',                                                            -- �����l-
										'UPDATE_DATE_TIME');                                                      ---�����l
	defaultVals := addQuota('0') || ', '			         		                    -- DELETE_SIGN                                                                 -- �����l-
						|| addQuota('        ') || ', '		         		                    -- DELETE_DATE                                                                  -- �����l-
						|| addQuota(' ')	 || ', '												--INSERT_USER_ID
						|| 'sysdate, '																--INSERT_DATE_TIME
						|| addQuota(' ')	 || ', '												--UPDATE_USER_ID
						|| 'sysdate'; 																--UPDATE_DATE_TIME
	
	colNames := getTblCols('CARD', extendCols, defaultCols);
	
	sql_str := 'INSERT /*APPEND*/ INTO CARD('				--�J�[�h-CARD
					|| getColsWithComma(extendCols)		--INSERT�ΏۃR�����i���Ԏw��̂��߁A�������ځj
					|| ', '
					|| colNames										--INSERT�ΏۃR�����i���Ԏw��̂��߁A�������f�[�^���ځj
					|| ', '
					|| getColsWithComma(defaultCols)	 	--INSERT�ΏۃR�����i���Ԏw��̂��߁A�f�t�H���g�l���ځj
					|| ') '
	
					|| 'SELECT TO_CHAR(' || max_CARD_NO || '+rownum), '			--��������-CARD_NO
					|| 'TO_CHAR(' || max_MEM_NO || '+rownum), '							--��������-MEM_NO
					|| colNames																			--�������f�[�^����
					|| ', '
					|| defaultVals 																		--�f�t�H���g�l����
					|| ' FROM (SELECT ' || colNames || ' FROM CARD M1 INNER JOIN '		--�������f�[�^���ڎ擾
					|| '(SELECT MEM_NO PK1, '													--������L�[���i��
					|| 'MAX(CARD_NO) PK2 '						--������L�[���i��
					|| 'FROM CARD '
					|| 'WHERE CARD.MEM_NO IN (SELECT MEM_NO FROM (' || specifySql || ')) '		--�i�����f�[�^����擾
					|| 'GROUP BY MEM_NO) S1 '	
					|| 'ON M1.MEM_NO = S1.PK1 '												--������L�[���i��
					|| 'AND M1.CARD_NO = S1.PK2 '			--������L�[���i��
					|| 'ORDER BY M1.MEM_NO)';													--�\�[�g�L�[�w��-MEM_NO
	
	sql_str := sql_str || ' WHERE rownum <= ' || extendTargetCnt;  --�����w��i�������͍ő匏���j
	
	--dbms_output.put_line(sql_str); --�e�X�g�p�ASQL�o��
	execute immediate sql_str;
	
	-- �����㑍����
	SELECT COUNT(*) INTO currentCnt FROM CARD;	
	dbms_output.put_line(logTblName || '�������{�㑍���� : ' || currentCnt);
	
	extendCnt := currentCnt - extendCnt; --����������ݒ肷��
	dbms_output.put_line(logTblName || '�������� : ' || extendCnt);

	---------------------------------------------------------
	
	---------------------------------------------------------
	-- �t�уJ�[�h-FUTAI_CARD
	logTblName := '�e�[�u�����F�t�уJ�[�h(FUTAI_CARD)�@';

	-- �����O������
	SELECT COUNT(*) INTO currentCnt FROM FUTAI_CARD;	
	dbms_output.put_line(logTblName || '�������{�O������ : ' || currentCnt);
	extendCnt := currentCnt; --�����Ώی�����ݒ肷��
	
	-- �t�уJ�[�h�Ǘ��ԍ��ő�l�擾
	SELECT MAX(FUTAI_CARD_KANRI_NO) INTO max_KEY1 FROM FUTAI_CARD;
	dbms_output.put_line(logTblName || '�t�уJ�[�h�Ǘ��ԍ��ő�l�擾 : ' || max_KEY1);
	
	extendCols := colArrays('FUTAI_CARD_KANRI_NO',
										'MEM_NO',
										'CARD_NO');
	defaultCols := colArrays('DELETE_SIGN',                                                                 -- �����l-
										'DELETE_DATE',                                                                  -- �����l-
										'INSERT_USER_ID',                                                            ---�����l
										'INSERT_DATE_TIME',                                                        -- �����l-
										'UPDATE_USER_ID',                                                            -- �����l-
										'UPDATE_DATE_TIME');                                                      ---�����l
	defaultVals := addQuota('0') || ', '			         		                    -- DELETE_SIGN                                                                 -- �����l-
						|| addQuota('        ') || ', '		         		                    -- DELETE_DATE                                                                  -- �����l-
						|| addQuota(' ')	 || ', '												--INSERT_USER_ID
						|| 'sysdate, '																--INSERT_DATE_TIME
						|| addQuota(' ')	 || ', '												--UPDATE_USER_ID
						|| 'sysdate'; 																--UPDATE_DATE_TIME
	
	colNames := getTblCols('FUTAI_CARD', extendCols, defaultCols);
	
	sql_str := 'INSERT /*APPEND*/ INTO FUTAI_CARD('				--�t�уJ�[�h-FUTAI_CARD
					|| getColsWithComma(extendCols)		--INSERT�ΏۃR�����i���Ԏw��̂��߁A�������ځj
					|| ', '
					|| colNames										--INSERT�ΏۃR�����i���Ԏw��̂��߁A�������f�[�^���ځj
					|| ', '
					|| getColsWithComma(defaultCols)	 	--INSERT�ΏۃR�����i���Ԏw��̂��߁A�f�t�H���g�l���ځj
					|| ') '
	
					|| 'SELECT TO_CHAR(' || max_KEY1 || '+rownum), '			--��������-FUTAI_CARD_KANRI_NO
					|| 'TO_CHAR(' || max_MEM_NO || '+rownum), '							--��������-MEM_NO
					|| 'TO_CHAR(' || max_CARD_NO || '+rownum), '							--��������-CARD_NO
					|| colNames																			--�������f�[�^����
					|| ', '
					|| defaultVals 																		--�f�t�H���g�l����
					|| ' FROM (SELECT ' || colNames || ' FROM FUTAI_CARD M1 INNER JOIN '		--�������f�[�^���ڎ擾
					|| '(SELECT MEM_NO PK1, '													--������L�[���i��
					|| 'MAX(FUTAI_CARD_KANRI_NO) PK2, '						--������L�[���i��
					|| 'MAX(CARD_NO) PK3 '						--������L�[���i��
					|| 'FROM FUTAI_CARD '
					|| 'WHERE FUTAI_CARD.MEM_NO IN (SELECT MEM_NO FROM (' || specifySql || ')) '		--�i�����f�[�^����擾
					|| 'GROUP BY MEM_NO) S1 '	
					|| 'ON M1.MEM_NO = S1.PK1 '												--������L�[���i��
					|| 'AND M1.FUTAI_CARD_KANRI_NO = S1.PK2 '			--������L�[���i��
					|| 'AND M1.CARD_NO = S1.PK3 '			--������L�[���i��
					|| 'ORDER BY M1.MEM_NO)';													--�\�[�g�L�[�w��-MEM_NO
	
	sql_str := sql_str || ' WHERE rownum <= ' || extendTargetCnt;  --�����w��i�������͍ő匏���j
	
	--dbms_output.put_line(sql_str); --�e�X�g�p�ASQL�o��
	execute immediate sql_str;
	
	-- �����㑍����
	SELECT COUNT(*) INTO currentCnt FROM FUTAI_CARD;	
	dbms_output.put_line(logTblName || '�������{�㑍���� : ' || currentCnt);
	
	extendCnt := currentCnt - extendCnt; --����������ݒ肷��
	dbms_output.put_line(logTblName || '�������� : ' || extendCnt);

	---------------------------------------------------------
	
	---------------------------------------------------------
	-- ���F����c��-AUTH_URI_ZAN
	logTblName := '�e�[�u�����F���F����c��(AUTH_URI_ZAN)�@';

	-- �����O������
	SELECT COUNT(*) INTO currentCnt FROM AUTH_URI_ZAN;	
	dbms_output.put_line(logTblName || '�������{�O������ : ' || currentCnt);
	extendCnt := currentCnt; --�����Ώی�����ݒ肷��
	
	extendCols := colArrays('MEM_NO');
	defaultCols := colArrays('DELETE_SIGN',                                                                 -- �����l-
										'DELETE_DATE',                                                                  -- �����l-
										'INSERT_USER_ID',                                                            ---�����l
										'INSERT_DATE_TIME',                                                        -- �����l-
										'UPDATE_USER_ID',                                                            -- �����l-
										'UPDATE_DATE_TIME',                                                            -- �����l-
										'VERSION');                                                      ---�����l
	defaultVals := addQuota('0') || ', '			         		                    -- DELETE_SIGN                                                                 -- �����l-
						|| addQuota('        ') || ', '		         		                    -- DELETE_DATE                                                                  -- �����l-
						|| addQuota(' ')	 || ', '												--INSERT_USER_ID
						|| 'sysdate, '																--INSERT_DATE_TIME
						|| addQuota(' ')	 || ', '												--UPDATE_USER_ID
						|| 'sysdate, 1'; 																--UPDATE_DATE_TIME,VERSION
	
	colNames := getTblCols('AUTH_URI_ZAN', extendCols, defaultCols);
	
	sql_str := 'INSERT /*APPEND*/ INTO AUTH_URI_ZAN('				--���F����c��-AUTH_URI_ZAN
					|| getColsWithComma(extendCols)		--INSERT�ΏۃR�����i���Ԏw��̂��߁A�������ځj
					|| ', '
					|| colNames										--INSERT�ΏۃR�����i���Ԏw��̂��߁A�������f�[�^���ځj
					|| ', '
					|| getColsWithComma(defaultCols)	 	--INSERT�ΏۃR�����i���Ԏw��̂��߁A�f�t�H���g�l���ځj
					|| ') '
	
					|| 'SELECT TO_CHAR(' || max_MEM_NO || '+rownum), '							--��������-MEM_NO
					|| colNames																			--�������f�[�^����
					|| ', '
					|| defaultVals 																		--�f�t�H���g�l����
					|| ' FROM (SELECT ' || colNames || ' FROM AUTH_URI_ZAN WHERE '		--�������f�[�^���ڎ擾
					|| ' AUTH_URI_ZAN.MEM_NO IN (SELECT MEM_NO FROM (' || specifySql || '))'		--�i�����f�[�^����擾�FDISTINCT�ς݂̂��߁A�či��s�v
					|| ' ORDER BY AUTH_URI_ZAN.MEM_NO)';															--�\�[�g�L�[�w��-MEM_NO
	
	sql_str := sql_str || ' WHERE rownum <= ' || extendTargetCnt;  --�����w��i�������͍ő匏���j
	
	--dbms_output.put_line(sql_str); --�e�X�g�p�ASQL�o��
	execute immediate sql_str;
	
	-- �����㑍����
	SELECT COUNT(*) INTO currentCnt FROM AUTH_URI_ZAN;	
	dbms_output.put_line(logTblName || '�������{�㑍���� : ' || currentCnt);
	
	extendCnt := currentCnt - extendCnt; --����������ݒ肷��
	dbms_output.put_line(logTblName || '�������� : ' || extendCnt);

	---------------------------------------------------------
	
	---------------------------------------------------------
	-- �_��c��-KYK_ZAN
	logTblName := '�e�[�u�����F�_��c��(KYK_ZAN)�@';

	-- �����O������
	SELECT COUNT(*) INTO currentCnt FROM KYK_ZAN;	
	dbms_output.put_line(logTblName || '�������{�O������ : ' || currentCnt);
	extendCnt := currentCnt; --�����Ώی�����ݒ肷��
	
	extendCols := colArrays('MEM_NO',
										'CST_NO');
	defaultCols := colArrays('DELETE_SIGN',                                                                 -- �����l-
										'DELETE_DATE',                                                                  -- �����l-
										'INSERT_USER_ID',                                                            ---�����l
										'INSERT_DATE_TIME',                                                        -- �����l-
										'UPDATE_USER_ID',                                                            -- �����l-
										'UPDATE_DATE_TIME',                                                            -- �����l-
										'VERSION');                                                      ---�����l
	defaultVals := addQuota('0') || ', '			         		                    -- DELETE_SIGN                                                                 -- �����l-
						|| addQuota('        ') || ', '		         		                    -- DELETE_DATE                                                                  -- �����l-
						|| addQuota(' ')	 || ', '												--INSERT_USER_ID
						|| 'sysdate, '																--INSERT_DATE_TIME
						|| addQuota(' ')	 || ', '												--UPDATE_USER_ID
						|| 'sysdate, 1'; 																--UPDATE_DATE_TIME,VERSION
	
	colNames := getTblCols('KYK_ZAN', extendCols, defaultCols);
	
	sql_str := 'INSERT /*APPEND*/ INTO KYK_ZAN('				--�_��c��-KYK_ZAN
					|| getColsWithComma(extendCols)		--INSERT�ΏۃR�����i���Ԏw��̂��߁A�������ځj
					|| ', '
					|| colNames										--INSERT�ΏۃR�����i���Ԏw��̂��߁A�������f�[�^���ځj
					|| ', '
					|| getColsWithComma(defaultCols)	 	--INSERT�ΏۃR�����i���Ԏw��̂��߁A�f�t�H���g�l���ځj
					|| ') '
	
					|| 'SELECT TO_CHAR(' || max_MEM_NO || '+rownum), '							--��������-MEM_NO
					|| 'TO_CHAR(' || max_CST_NO || '+rownum), '							--��������-CST_NO
					|| colNames																			--�������f�[�^����
					|| ', '
					|| defaultVals 																		--�f�t�H���g�l����
					|| ' FROM (SELECT ' || colNames || ' FROM KYK_ZAN WHERE '		--�������f�[�^���ڎ擾
					|| ' KYK_ZAN.MEM_NO IN (SELECT MEM_NO FROM (' || specifySql || '))'		--�i�����f�[�^����擾�FDISTINCT�ς݂̂��߁A�či��s�v
					|| ' ORDER BY KYK_ZAN.MEM_NO)';															--�\�[�g�L�[�w��-MEM_NO
	
	sql_str := sql_str || ' WHERE rownum <= ' || extendTargetCnt;  --�����w��i�������͍ő匏���j
	
	--dbms_output.put_line(sql_str); --�e�X�g�p�ASQL�o��
	execute immediate sql_str;
	
	-- �����㑍����
	SELECT COUNT(*) INTO currentCnt FROM KYK_ZAN;	
	dbms_output.put_line(logTblName || '�������{�㑍���� : ' || currentCnt);
	
	extendCnt := currentCnt - extendCnt; --����������ݒ肷��
	dbms_output.put_line(logTblName || '�������� : ' || extendCnt);

	---------------------------------------------------------
	
	---------------------------------------------------------
	-- ����-KZ
	logTblName := '�e�[�u�����F����(KZ)�@';

	-- �����O������
	SELECT COUNT(*) INTO currentCnt FROM KZ;	
	dbms_output.put_line(logTblName || '�������{�O������ : ' || currentCnt);
	extendCnt := currentCnt; --�����Ώی�����ݒ肷��
	
	-- �����Ǘ��ԍ��ő�l�擾
	SELECT MAX(KZ_KANRI_NO) INTO max_KEY1 FROM KZ;
	dbms_output.put_line(logTblName || '�����Ǘ��ԍ��ő�l�擾 : ' || max_KEY1);
	
	extendCols := colArrays('KZ_KANRI_NO');
	defaultCols := colArrays('DELETE_SIGN',                                                                 -- �����l-
										'DELETE_DATE',                                                                  -- �����l-
										'INSERT_USER_ID',                                                            ---�����l
										'INSERT_DATE_TIME',                                                        -- �����l-
										'UPDATE_USER_ID',                                                            -- �����l-
										'UPDATE_DATE_TIME',                                                            -- �����l-
										'VERSION');                                                      ---�����l
	defaultVals := addQuota('0') || ', '			         		                    -- DELETE_SIGN                                                                 -- �����l-
						|| addQuota('        ') || ', '		         		                    -- DELETE_DATE                                                                  -- �����l-
						|| addQuota(' ')	 || ', '												--INSERT_USER_ID
						|| 'sysdate, '																--INSERT_DATE_TIME
						|| addQuota(' ')	 || ', '												--UPDATE_USER_ID
						|| 'sysdate, 1'; 																--UPDATE_DATE_TIME,VERSION
	
	colNames := getTblCols('KZ', extendCols, defaultCols);
	
	sql_str := 'INSERT /*APPEND*/ INTO KZ('				--����-KZ
					|| getColsWithComma(extendCols)		--INSERT�ΏۃR�����i���Ԏw��̂��߁A�������ځj
					|| ', '
					|| colNames										--INSERT�ΏۃR�����i���Ԏw��̂��߁A�������f�[�^���ځj
					|| ', '
					|| getColsWithComma(defaultCols)	 	--INSERT�ΏۃR�����i���Ԏw��̂��߁A�f�t�H���g�l���ځj
					|| ') '
	
					|| 'SELECT TO_CHAR(' || max_KEY1 || '+rownum), '			--��������-KZ_KANRI_NO
					|| colNames																			--�������f�[�^����
					|| ', '
					|| defaultVals 																		--�f�t�H���g�l����
					|| ' FROM (SELECT ' || colNames || ' FROM KZ M1 INNER JOIN '		--�������f�[�^���ڎ擾
					|| '(SELECT MEM_NO PK1, '													--������L�[���i��
					|| 'MAX(KYK_KZ_KANRI_NO) PK2, '						--������L�[���i��
					|| 'MAX(KZ_KANRI_NO) PK3 '						--������L�[���i��
					|| 'FROM KYK_KZ '
					|| 'WHERE KYK_KZ.MEM_NO IN (SELECT MEM_NO FROM (' || specifySql || ')) '		--�i�����f�[�^����擾
					|| 'GROUP BY MEM_NO) S1 '	
					|| 'ON M1.KZ_KANRI_NO = S1.PK3 '			--������L�[���i��
					|| 'ORDER BY S1.PK1)';													--�\�[�g�L�[�w��-MEM_NO
	
	sql_str := sql_str || ' WHERE rownum <= ' || extendTargetCnt;  --�����w��i�������͍ő匏���j
	
	--dbms_output.put_line(sql_str); --�e�X�g�p�ASQL�o��
	execute immediate sql_str;
	
	-- �����㑍����
	SELECT COUNT(*) INTO currentCnt FROM KZ;	
	dbms_output.put_line(logTblName || '�������{�㑍���� : ' || currentCnt);
	
	extendCnt := currentCnt - extendCnt; --����������ݒ肷��
	dbms_output.put_line(logTblName || '�������� : ' || extendCnt);

	---------------------------------------------------------
	
	---------------------------------------------------------
	-- �_�����-KYK_KZ �i�֘A�����邩��A�����e�[�u���̌�ő����j
	logTblName := '�e�[�u�����F�_�����(KYK_KZ)�@';

	-- �����O������
	SELECT COUNT(*) INTO currentCnt FROM KYK_KZ;	
	dbms_output.put_line(logTblName || '�������{�O������ : ' || currentCnt);
	extendCnt := currentCnt; --�����Ώی�����ݒ肷��
	
	-- �_������Ǘ��ԍ��ő�l�擾
	SELECT MAX(KYK_KZ_KANRI_NO) INTO max_KEY1 FROM KYK_KZ;
	dbms_output.put_line(logTblName || '�_������Ǘ��ԍ��ő�l�擾 : ' || max_KEY1);
	-- �����Ǘ��ԍ��ő�l�擾
	SELECT MAX(KZ_KANRI_NO) INTO max_KEY2 FROM KZ;
	dbms_output.put_line(logTblName || '�����Ǘ��ԍ��ő�l�擾 : ' || max_KEY2);
	
	extendCols := colArrays('KYK_KZ_KANRI_NO',
										'MEM_NO',
										'KZ_KANRI_NO');
	defaultCols := colArrays('DELETE_SIGN',                                                                 -- �����l-
										'DELETE_DATE',                                                                  -- �����l-
										'INSERT_USER_ID',                                                            ---�����l
										'INSERT_DATE_TIME',                                                        -- �����l-
										'UPDATE_USER_ID',                                                            -- �����l-
										'UPDATE_DATE_TIME');                                                      ---�����l
	defaultVals := addQuota('0') || ', '			         		                    -- DELETE_SIGN                                                                 -- �����l-
						|| addQuota('        ') || ', '		         		                    -- DELETE_DATE                                                                  -- �����l-
						|| addQuota(' ')	 || ', '												--INSERT_USER_ID
						|| 'sysdate, '																--INSERT_DATE_TIME
						|| addQuota(' ')	 || ', '												--UPDATE_USER_ID
						|| 'sysdate'; 																--UPDATE_DATE_TIME
	
	colNames := getTblCols('KYK_KZ', extendCols, defaultCols);
	
	sql_str := 'INSERT /*APPEND*/ INTO KYK_KZ('				--�_�����-KYK_KZ
					|| getColsWithComma(extendCols)		--INSERT�ΏۃR�����i���Ԏw��̂��߁A�������ځj
					|| ', '
					|| colNames										--INSERT�ΏۃR�����i���Ԏw��̂��߁A�������f�[�^���ځj
					|| ', '
					|| getColsWithComma(defaultCols)	 	--INSERT�ΏۃR�����i���Ԏw��̂��߁A�f�t�H���g�l���ځj
					|| ') '
	
					|| 'SELECT TO_CHAR(' || max_KEY1 || '+rownum), '			--��������-KYK_KZ_KANRI_NO
					|| 'TO_CHAR(' || max_MEM_NO || '+rownum), '							--��������-MEM_NO
					|| 'TO_CHAR(' || max_KEY2 || '+rownum), '							--��������-KZ_KANRI_NO
					|| colNames																			--�������f�[�^����
					|| ', '
					|| defaultVals 																		--�f�t�H���g�l����
					|| ' FROM (SELECT ' || colNames || ' FROM KYK_KZ M1 INNER JOIN '		--�������f�[�^���ڎ擾
					|| '(SELECT MEM_NO PK1, '													--������L�[���i��
					|| 'MAX(KYK_KZ_KANRI_NO) PK2 '						--������L�[���i��
					|| 'FROM KYK_KZ '
					|| 'WHERE KYK_KZ.MEM_NO IN (SELECT MEM_NO FROM (' || specifySql || ')) '		--�i�����f�[�^����擾
					|| 'GROUP BY MEM_NO) S1 '	
					|| 'ON M1.MEM_NO = S1.PK1 '												--������L�[���i��
					|| 'AND M1.KYK_KZ_KANRI_NO = S1.PK2 '			--������L�[���i��
					|| 'ORDER BY M1.MEM_NO)';													--�\�[�g�L�[�w��-MEM_NO
	
	sql_str := sql_str || ' WHERE rownum <= ' || extendTargetCnt;  --�����w��i�������͍ő匏���j
	
	--dbms_output.put_line(sql_str); --�e�X�g�p�ASQL�o��
	execute immediate sql_str;
	
	-- �����㑍����
	SELECT COUNT(*) INTO currentCnt FROM KYK_KZ;	
	dbms_output.put_line(logTblName || '�������{�㑍���� : ' || currentCnt);
	
	extendCnt := currentCnt - extendCnt; --����������ݒ肷��
	dbms_output.put_line(logTblName || '�������� : ' || extendCnt);

	---------------------------------------------------------
	
	
	---------------------------------------------------------
	-- �_��ڋq�֘A-KYK_CST_KANREN �i�֘A�����邩��A�Ō�ő����j
	logTblName := '�e�[�u�����F�_��ڋq�֘A(KYK_CST_KANREN)�@';

	-- �����O������
	SELECT COUNT(*) INTO currentCnt FROM KYK_CST_KANREN;	
	dbms_output.put_line(logTblName || '�������{�O������ : ' || currentCnt);
	extendCnt := currentCnt; --�����Ώی�����ݒ肷��
	
	-- �_��ڋq�֘A�ԍ��ő�l�擾
	SELECT MAX(KYK_CST_KANREN_NO) INTO max_KEY1 FROM KYK_CST_KANREN;
	dbms_output.put_line(logTblName || '�_��ڋq�֘A�ԍ��ő�l�擾 : ' || max_KEY1);
	-- �\���ԍ��ő�l�擾
	SELECT MAX(MOSIKOMI_NO) INTO max_KEY2 FROM KYK_CST_KANREN;
	dbms_output.put_line(logTblName || '�\���ԍ��ő�l�擾 : ' || max_KEY2);
	
	extendCols := colArrays('KYK_CST_KANREN_NO',
										'MEM_NO',
										'CST_NO',
										'MOSIKOMI_NO',
										'CARD_NO');
	defaultCols := colArrays('CARD_HAKKO_SIGN',                                                        -- �J�[�h���s�L�T�C���F�L�F1
										'DELETE_SIGN',                                                                  -- �����l-
										'DELETE_DATE',                                                                  -- �����l-
										'INSERT_USER_ID',                                                            ---�����l
										'INSERT_DATE_TIME',                                                        -- �����l-
										'UPDATE_USER_ID',                                                            -- �����l-
										'UPDATE_DATE_TIME');                                                      ---�����l
	defaultVals := addQuota('1') || ', '			         		                    -- CARD_HAKKO_SIGN �F�L�F1
						|| addQuota('0') || ', '		         		                    -- DELETE_SIGN                                                                  -- �����l-
						|| addQuota('        ') || ', '		         		                    -- DELETE_DATE                                                                  -- �����l-
						|| addQuota(' ')	 || ', '												--INSERT_USER_ID
						|| 'sysdate, '																--INSERT_DATE_TIME
						|| addQuota(' ')	 || ', '												--UPDATE_USER_ID
						|| 'sysdate'; 																--UPDATE_DATE_TIME
	
	colNames := getTblCols('KYK_CST_KANREN', extendCols, defaultCols);
	
	sql_str := 'INSERT /*APPEND*/ INTO KYK_CST_KANREN('				--�_��ڋq�֘A-KYK_CST_KANREN
					|| getColsWithComma(extendCols)		--INSERT�ΏۃR�����i���Ԏw��̂��߁A�������ځj
					|| ', '
					|| colNames										--INSERT�ΏۃR�����i���Ԏw��̂��߁A�������f�[�^���ځj
					|| ', '
					|| getColsWithComma(defaultCols)	 	--INSERT�ΏۃR�����i���Ԏw��̂��߁A�f�t�H���g�l���ځj
					|| ') '
	
					|| 'SELECT TO_CHAR(' || max_KEY1 || '+rownum), '			--��������-KYK_CST_KANREN_NO
					|| 'TO_CHAR(' || max_MEM_NO || '+rownum), '							--��������-MEM_NO
					|| 'TO_CHAR(' || max_CST_NO || '+rownum), '							--��������-CST_NO
					|| 'TO_CHAR(' || max_KEY2 || '+rownum), '							--��������-MOSIKOMI_NO
					|| 'TO_CHAR(' || max_CARD_NO || '+rownum), '							--��������-CARD_NO
					|| colNames																			--�������f�[�^����
					|| ', '
					|| defaultVals 																		--�f�t�H���g�l����
					|| ' FROM (SELECT ' || colNames || ' FROM KYK_CST_KANREN '		--�������f�[�^���ڎ擾
					|| ' INNER JOIN (' || specifySql || ') S1'		--�i�����f�[�^����擾
					|| ' ON S1.KYK_CST_KANREN_NO = KYK_CST_KANREN.KYK_CST_KANREN_NO'
					|| ' ORDER BY S1.MEM_NO)';															--�\�[�g�L�[�w��-MEM_NO
	
	sql_str := sql_str || ' WHERE rownum <= ' || extendTargetCnt;  --�����w��i�������͍ő匏���j
	
	--dbms_output.put_line(sql_str); --�e�X�g�p�ASQL�o��
	execute immediate sql_str;
	
	-- �����㑍����
	SELECT COUNT(*) INTO currentCnt FROM KYK_CST_KANREN;	
	dbms_output.put_line(logTblName || '�������{�㑍���� : ' || currentCnt);
	
	extendCnt := currentCnt - extendCnt; --����������ݒ肷��
	dbms_output.put_line(logTblName || '�������� : ' || extendCnt);

	---------------------------------------------------------
	
	---------------------------------------------------------
	-- ��J�[�h�_��ڋq�֘A-HI_CARD_KYK_CST_KANREN
	logTblName := '�e�[�u�����F��J�[�h�_��ڋq�֘A(HI_CARD_KYK_CST_KANREN)�@';

	-- �����O������
	SELECT COUNT(*) INTO currentCnt FROM HI_CARD_KYK_CST_KANREN;	
	dbms_output.put_line(logTblName || '�������{�O������ : ' || currentCnt);
	extendCnt := currentCnt; --�����Ώی�����ݒ肷��
	
	-- �_��ڋq�֘A�ԍ��ő�l�擾
	SELECT MAX(KYK_CST_KANREN_NO) INTO max_KEY1 FROM HI_CARD_KYK_CST_KANREN;
	dbms_output.put_line(logTblName || '�_��ڋq�֘A�ԍ��ő�l�擾 : ' || max_KEY1);
	-- �\���ԍ��ő�l�擾
	max_KEY2 := 0;
	
	extendCols := colArrays('KYK_CST_KANREN_NO',
										'MEM_NO',
										'CST_NO',
										'MOSIKOMI_NO',
										'CARD_NO');
	defaultCols := colArrays('CARD_HAKKO_SIGN',                                                        -- �J�[�h���s�L�T�C���F�L�F1
										'DELETE_SIGN',                                                                  -- �����l-
										'DELETE_DATE',                                                                  -- �����l-
										'INSERT_USER_ID',                                                            ---�����l
										'INSERT_DATE_TIME',                                                        -- �����l-
										'UPDATE_USER_ID',                                                            -- �����l-
										'UPDATE_DATE_TIME');                                                      ---�����l
	defaultVals := addQuota('1') || ', '			         		                    -- CARD_HAKKO_SIGN �F�L�F1
						|| addQuota('0') || ', '		         		                    -- DELETE_SIGN                                                                  -- �����l-
						|| addQuota('        ') || ', '		         		                    -- DELETE_DATE                                                                  -- �����l-
						|| addQuota(' ')	 || ', '												--INSERT_USER_ID
						|| 'sysdate, '																--INSERT_DATE_TIME
						|| addQuota(' ')	 || ', '												--UPDATE_USER_ID
						|| 'sysdate'; 																--UPDATE_DATE_TIME
	
	colNames := getTblCols('HI_CARD_KYK_CST_KANREN', extendCols, defaultCols);
	
	sql_str := 'INSERT /*APPEND*/ INTO HI_CARD_KYK_CST_KANREN('				--��J�[�h�_��ڋq�֘A-HI_CARD_KYK_CST_KANREN
					|| getColsWithComma(extendCols)		--INSERT�ΏۃR�����i���Ԏw��̂��߁A�������ځj
					|| ', '
					|| colNames										--INSERT�ΏۃR�����i���Ԏw��̂��߁A�������f�[�^���ځj
					|| ', '
					|| getColsWithComma(defaultCols)	 	--INSERT�ΏۃR�����i���Ԏw��̂��߁A�f�t�H���g�l���ځj
					|| ') '
	
					|| 'SELECT TO_CHAR(' || max_KEY1 || '+rownum), '			--��������-KYK_CST_KANREN_NO
					|| 'TO_CHAR(' || max_MEM_NO || '+rownum), '							--��������-MEM_NO
					|| 'TO_CHAR(' || max_CST_NO || '+rownum), '							--��������-CST_NO
					|| 'TO_CHAR(' || max_KEY2 || '+rownum), '							--��������-MOSIKOMI_NO
					|| 'TO_CHAR(' || max_CARD_NO || '+rownum), '							--��������-CARD_NO
					|| colNames																			--�������f�[�^����
					|| ', '
					|| defaultVals 																		--�f�t�H���g�l����
					|| ' FROM (SELECT ' || colNames || ' FROM HI_CARD_KYK_CST_KANREN '		--�������f�[�^���ڎ擾
					|| ' ORDER BY MEM_NO)';															--�\�[�g�L�[�w��-MEM_NO
	
	sql_str := sql_str || ' WHERE rownum <= ' || extendTargetCnt;  --�����w��i�������͍ő匏���j
	
	--dbms_output.put_line(sql_str); --�e�X�g�p�ASQL�o��
	execute immediate sql_str;
	
	-- �����㑍����
	SELECT COUNT(*) INTO currentCnt FROM HI_CARD_KYK_CST_KANREN;	
	dbms_output.put_line(logTblName || '�������{�㑍���� : ' || currentCnt);
	
	extendCnt := currentCnt - extendCnt; --����������ݒ肷��
	dbms_output.put_line(logTblName || '�������� : ' || extendCnt);

	---------------------------------------------------------
	
	-- �������{�㑍����
	sql_str := 'SELECT COUNT(*) FROM (' || specifySql || ')';	
	execute immediate sql_str into currentCnt;
	dbms_output.put_line('�������{�㑍���� : ' || currentCnt);
	
end doubleSkyTables;
/
