CREATE DEFINER=`admin_user`@`%` PROCEDURE `proc_upe`()
BEGIN
	# Process data from upe_staging to upe_main. Must be performed before proc_epe
    
    # Step 1: Prepare
    DELETE FROM tmp_upe_staging;
    DELETE FROM tmp_upe_main;
    INSERT INTO tmp_upe_staging SELECT * FROM upe_staging;
    
    # Step 2: Fix values
    UPDATE tmp_upe_staging SET upe_vendor = 'NOKIA' WHERE upe_vendor IN ('ALCATEL', 'ALCATEL-LUCENT', 'LUCENT');
    UPDATE tmp_upe_staging SET epe_card = NULL WHERE epe_card = '';
    UPDATE tmp_upe_staging SET role = NULL WHERE role = '';
    UPDATE tmp_upe_staging SET service_sla_slg = NULL WHERE service_sla_slg = '';
    UPDATE tmp_upe_staging SET physical_group_slg = NULL WHERE physical_group_slg = '';
    
    # Step 3: Clean up
    
    # Error Type 1
    DELETE FROM tmp_upe_staging WHERE red_group_id = '';
    SET affectedRow = (SELECT ROW_COUNT());
    if affectedRow > 0 then
		INSERT INTO metroe_error(table_name, remarks, occurrences) VALUE('upe_staging', 'Empty red_group_id', affectedRow);
	end if;
    
    # Error Type 2
    DELETE FROM tmp_upe_staging WHERE LENGTH(epe_port) > 2;
	SET affectedRow = (SELECT ROW_COUNT());
    if affectedRow > 0 then
		INSERT INTO metroe_error(table_name, remarks, occurrences) VALUE('upe_staging', 'Length epe_port >2', affectedRow);
	end if;
    
    # Error Type 3
    DELETE FROM tmp_upe_staging WHERE role IN ('1', '2');
    if affectedRow > 0 then
		INSERT INTO metroe_error(table_name, remarks, occurrences) VALUE('upe_staging', 'Role is not in format PRIMARY/SECONDARY/ACTIVE/PASSIVE', affectedRow);
	end if;
    
	# Error Type 4
    DELETE FROM tmp_upe_staging WHERE epe_card = NULL OR epe_card = '';
    if affectedRow > 0 then
		INSERT INTO metroe_error(table_name, remarks, occurrences) VALUE('upe_staging', 'Missing epe_card information', affectedRow);
	end if;
    
	# Error Type 5
    DELETE FROM tmp_upe_staging WHERE role = NULL OR role = '';
    if affectedRow > 0 then
		INSERT INTO metroe_error(table_name, remarks, occurrences) VALUE('upe_staging', 'Missing role information', affectedRow);
	end if;
    
	# Error Type 6
    DELETE FROM tmp_upe_staging WHERE service_sla_slg = NULL OR service_sla_slg = '';
    if affectedRow > 0 then
		INSERT INTO metroe_error(table_name, remarks, occurrences) VALUE('upe_staging', 'Missing service_sla_slg information', affectedRow);
	end if;
    
	# Error Type 7
    DELETE FROM tmp_upe_staging WHERE physical_group_slg = NULL OR physical_group_slg = '';
    if affectedRow > 0 then
		INSERT INTO metroe_error(table_name, remarks, occurrences) VALUE('upe_staging', 'Missing service_sla_slg information', affectedRow);
	end if;
    
    DELETE FROM tmp_upe_staging WHERE upe_port_status NOT IN ('Activated', 'Available', 'In Service');
    
    # Step 4: Populate tmp_upe_main
    INSERT INTO tmp_upe_main (bandwidth,red_group_id,upe_name,upe_vendor,upe_model,upe_port_status,epe_name,epe_card,epe_slot,epe_port,role,service_sla_slg,physical_group_slg,primary_no) SELECT bandwidth,red_group_id,upe_name,upe_vendor,upe_model,upe_port_status,epe_name,epe_card,epe_slot,epe_port,role,service_sla_slg,physical_group_slg,primary_no FROM tmp_upe_staging;
    
    # Step 5: Populate the upe_main
    DELETE FROM upe_main;
    
    INSERT INTO upe_main SELECT * FROM tmp_upe_main;
END