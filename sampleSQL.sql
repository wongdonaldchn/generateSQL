SELECT TO_CHAR(SYSDATE,'YYYY/MM/DD HH24:MI:SS') FROM DUAL;

declare
begin

--insert into target tables
insert into IC_CRD_SBT_KRK_MTR(KSM_YKK,JZN_DM_SKT,BKT_KRK_SRT,KSG_YKK,TME_SMP) values ('201809', '201804', '201806', '202307','20180129123456');
insert into IC_CRD_SBT_KRK_MTR(KSM_YKK,JZN_DM_SKT,BKT_KRK_SRT,KSG_YKK,TME_SMP) values ('201810', '201805', '201807', '202308','20180129123456');

commit;
end;
/
SELECT TO_CHAR(SYSDATE,'YYYY/MM/DD HH24:MI:SS') FROM DUAL;