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
    
    # Error Type 1 (FARHA please compare with test_upe)
    DELETE FROM tmp_upe_staging WHERE red_group_id = '';
    
    # Error Type 2 (FARHA)
    DELETE FROM tmp_upe_staging WHERE LENGTH(epe_port) > 2;
    
    # Error Type 3 (FARHA)
    DELETE FROM tmp_upe_staging WHERE role IN ('1', '2');
    
    DELETE FROM tmp_upe_staging WHERE upe_port_status NOT IN ('Activated', 'Available', 'In Service');
    
    # Step 4: Populate tmp_upe_main
    INSERT INTO tmp_upe_main (bandwidth,red_group_id,upe_name,upe_vendor,upe_model,upe_port_status,epe_name,epe_card,epe_slot,epe_port,role,service_sla_slg,physical_group_slg,primary_no) SELECT bandwidth,red_group_id,upe_name,upe_vendor,upe_model,upe_port_status,epe_name,epe_card,epe_slot,epe_port,role,service_sla_slg,physical_group_slg,primary_no FROM tmp_upe_staging;
    
    # Step 5: Populate the upe_main
    DELETE FROM upe_main;
    INSERT INTO upe_main SELECT * FROM tmp_upe_main;
    
END