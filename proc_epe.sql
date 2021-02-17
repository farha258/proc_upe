CREATE DEFINER=`admin_user`@`%` PROCEDURE `proc_epe`()
BEGIN
	# Process epe_staging to epe_main
    DECLARE affectedRow INT;
    DECLARE occurrences INT;
    
    # Step 1: Prepare
    DELETE FROM tmp_epe_staging;
    DELETE FROM tmp_epe_main;
    INSERT INTO tmp_epe_staging SELECT * FROM epe_staging;
    
    # Step 2: Normalize
    UPDATE tmp_epe_staging SET vendor = 'NOKIA' WHERE vendor IN ('ALCATEL', 'ALCATEL-LUCENT', 'LUCENT');
    UPDATE tmp_epe_staging SET ip = REPLACE(ip, '\r', '');
    UPDATE tmp_epe_staging SET epe_name = NULL WHERE epe_name = '';
    UPDATE tmp_epe_staging SET ip = NULL WHERE ip = '';
    
    # Step 3: Clean up
    DELETE FROM tmp_epe_staging WHERE epe_name LIKE '%-SH%';
    DELETE FROM tmp_epe_staging WHERE status NOT IN ('In Service', 'Pending Installation');
    DELETE FROM tmp_epe_staging WHERE vendor NOT IN ('HUAWEI', 'NOKIA');
    DELETE FROM tmp_epe_staging WHERE epe_name IN (SELECT epe_name FROM epe_staging GROUP BY epe_name HAVING COUNT(*) > 1) AND status = 'Pending Installation';
    
    # Extra - update the metroe_error table to reflect the error with records
    
    # epe_name is null
    SET occurrences = (SELECT COUNT(*) FROM tmp_epe_staging WHERE epe_name IS NULL);
    if occurrences > 0 then
		INSERT INTO metroe_error(table_name, remarks, occurrences) VALUE('epe_staging', 'epe_name is empty', occurrences);
    end if;
    
    # ip is null
    SET occurrences = (SELECT COUNT(*) FROM tmp_epe_staging WHERE ip IS NULL);
    if occurrences > 0 then
		INSERT INTO metroe_error(table_name, remarks, occurrences) VALUE('epe_staging', 'ip is empty', occurrences);
    end if;
    
    # epe_name is not available in upe_main
    # remarks: we do it here because only during processing of epe is performed after upe
    SET occurrences = (SELECT COUNT(DISTINCT(epe_name)) FROM upe_main WHERE epe_name NOT IN (SELECT epe_name FROM tmp_epe_staging));
    if occurrences > 0 then
		INSERT INTO metroe_error(table_name, remarks, occurrences) VALUE('upe_staging', 'No matching epe_name', occurrences);
    end if;
    
    # Step 4: Finalize
    INSERT INTO tmp_epe_main(customer_id,ptt,exc,epe_name,status,vendor,model_eq,serial,ip) SELECT customer_id,ptt,exc,epe_name,status,vendor,model_eq,serial,ip FROM tmp_epe_staging;

	# Step 5: Now, ready to populate epe_main
    DELETE FROM epe_main;
    INSERT INTO epe_main SELECT * FROM tmp_epe_main;
    
END