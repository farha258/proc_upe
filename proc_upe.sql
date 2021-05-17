CREATE DEFINER=`admin_user`@`%` PROCEDURE `proc_upe`()
BEGIN
	# Process data from upe_staging to upe_main. Must be performed before proc_epe
    
	## For the sake of testing
    DECLARE affectedRow INT;
    DECLARE occurrences INT;
    
    # Step 1: Prepare
    TRUNCATE TABLE tmp_upe_staging;
    TRUNCATE TABLE tmp_upe_main;
    INSERT INTO tmp_upe_staging SELECT * FROM upe_staging;
    
    # Step 2: Fix values
    UPDATE tmp_upe_staging SET upe_vendor = 'NOKIA' WHERE upe_vendor IN ('ALCATEL', 'ALCATEL-LUCENT', 'LUCENT');
    UPDATE tmp_upe_staging SET epe_card = NULL WHERE epe_card = '';
    UPDATE tmp_upe_staging SET role = NULL WHERE role = '';
    UPDATE tmp_upe_staging SET service_sla_slg = NULL WHERE service_sla_slg = '';
    UPDATE tmp_upe_staging SET physical_group_slg = NULL WHERE physical_group_slg = '';
    
    # Step 3: Clean up
    
    # Error Type 1 (DELETE)
    DELETE FROM tmp_upe_staging WHERE red_group_id = '';
    SET affectedRow = (SELECT ROW_COUNT());
    if affectedRow > 0 then
		INSERT INTO metroe_error(table_name, remarks, occurrences) VALUE('upe_staging', 'Empty red_group_id', affectedRow);
	end if;
    
    # Error Type 2
    SET occurrences = (SELECT COUNT(*) FROM tmp_upe_staging WHERE epe_port NOT REGEXP '^-?[0-9]+$');
    if occurrences > 0 then
		INSERT INTO metroe_error(table_name, remarks, occurrences) VALUE('upe_staging', 'epe_port is not an integer', occurrences);
    end if;
    
    # Remarks: We update it here so that we can identify first how many is having issue
	UPDATE tmp_upe_staging SET epe_port = NULL WHERE epe_port NOT REGEXP '^-?[0-9]+$';

    # Error Type 3
    DELETE FROM tmp_upe_staging WHERE role NOT IN ('PRIMARY', 'SECONDARY', 'ACTIVE', 'PASSIVE');
    SET affectedRow = (SELECT ROW_COUNT());
    if affectedRow > 0 then
		INSERT INTO metroe_error(table_name, remarks, occurrences) VALUE('upe_staging', 'Role is not in format PRIMARY/SECONDARY/ACTIVE/PASSIVE', affectedRow);
	end if;
    
	# Error Type 3c
    SET occurrences = (SELECT COUNT(*) FROM tmp_upe_staging WHERE role IS NULL and upe_name not regexp '^[NE]');
    SET affectedRow = (SELECT ROW_COUNT());
    if affectedRow > 0 then
	INSERT INTO metroe_error(table_name, remarks, occurrences) VALUE('upe_staging', 'Need to be updated for role', affectedRow);
	end if;
    
    # Error Type 3b
    # DELETE FROM tmp_upe_staging WHERE role IS NULL;
    # SET affectedRow = (SELECT ROW_COUNT());
    # if affectedRow > 0 then
	#	INSERT INTO metroe_error(table_name, remarks, occurrences) VALUE('upe_staging', 'Role is NULL', affectedRow);
	# end if;
    
	# Error Type 4
    SET occurrences = (SELECT COUNT(*) FROM tmp_upe_staging WHERE epe_card IS NULL);
    if occurrences > 0 then
		INSERT INTO metroe_error(table_name, remarks, occurrences) VALUE('upe_staging', 'Missing epe_card information', occurrences);
    end if;
    
	# Error Type 5
    SET occurrences = (SELECT COUNT(*) FROM tmp_upe_staging WHERE role IS NULL);
    if occurrences > 0 then
		INSERT INTO metroe_error(table_name, remarks, occurrences) VALUE('upe_staging', 'Missing role information', occurrences);
    end if;
    
	# Error Type 6
    SET occurrences = (SELECT COUNT(*) FROM tmp_upe_staging WHERE service_sla_slg IS NULL);
    if occurrences > 0 then
		INSERT INTO metroe_error(table_name, remarks, occurrences) VALUE('upe_staging', 'Missing service_sla_slg information', occurrences);
    end if;
    
	# Error Type 7
    SET occurrences = (SELECT COUNT(*) FROM tmp_upe_staging WHERE physical_group_slg IS NULL);
    if occurrences > 0 then
		INSERT INTO metroe_error(table_name, remarks, occurrences) VALUE('upe_staging', 'Missing physical_group_slg information', occurrences);
    end if;
    
	# Error Type 8
    SET occurrences = (SELECT COUNT(*) FROM tmp_upe_staging WHERE length(primary_no) > 20);
    if occurrences > 0 then
		INSERT INTO metroe_error(table_name, remarks, occurrences) VALUE('upe_staging', 'primary_no length > 20 digit', occurrences);
    end if;
    
    DELETE FROM tmp_upe_staging WHERE upe_port_status NOT IN ('Activated', 'Available', 'In Service');
    
    # Step 4: Populate tmp_upe_main
    INSERT INTO tmp_upe_main (
			bandwidth,
			red_group_id,
			upe_name,
			upe_vendor,
			upe_model,
			upe_port_status,
			epe_name,
			epe_card,
			epe_slot,
			epe_port,
			role,
			service_sla_slg,
			physical_group_slg,
			primary_no, 
            qos,
			internet,
			consumer_internet,
			multimedia_data,
			business_internet,
			economy,
			standard_data,
			mission_critical,
			multimedia,
			premier,
			control,
			network_control,
			nbgh_plus_premier,
			red_id) 
    SELECT 
			bandwidth,
			red_group_id,
			upe_name,
			upe_vendor,
			upe_model,
			upe_port_status,
			epe_name,
			epe_card,
			epe_slot,
			epe_port,
			role,
			service_sla_slg,
			physical_group_slg,
			primary_no, 
            qos,
			internet,
			consumer_internet,
			multimedia_data,
			business_internet,
			economy,
			standard_data,
			mission_critical,
			multimedia,
			premier,
			control,
			network_control,
			nbgh_plus_premier,
			concat_ws('',red_group_id,'_',epe_name,'/',epe_card,'/',epe_slot,'/',epe_port,'/',primary_no,'_',role) as red_id FROM tmp_upe_staging group by red_id;

    # Step 5: Populate the upe_main
	INSERT INTO upe_main (
          bandwidth, 
          red_group_id,
          upe_name,
          upe_vendor,
          upe_model,
          upe_port_status,
          epe_name,
          epe_card,
          epe_slot,
          epe_port,
          role,
          service_sla_slg,
          physical_group_slg,
          primary_no,
          qos,
			internet,
			consumer_internet,
			multimedia_data,
			business_internet,
			economy,
			standard_data,
			mission_critical,
			multimedia,
			premier,
			control,
			network_control,
			nbgh_plus_premier,
          red_id) 
      SELECT 
          bandwidth, 
          red_group_id,
          upe_name,
          upe_vendor,
          upe_model,
          upe_port_status,
          epe_name,
          epe_card,
          epe_slot,
          epe_port,
          role,
          service_sla_slg,
          physical_group_slg,
          primary_no, 
          qos,
			internet,
			consumer_internet,
			multimedia_data,
			business_internet,
			economy,
			standard_data,
			mission_critical,
			multimedia,
			premier,
			control,
			network_control,
			nbgh_plus_premier,
          red_id 
      FROM tmp_upe_main AS a
      ON DUPLICATE KEY UPDATE 
		bandwidth = a.bandwidth, 
        red_group_id = a.red_group_id,
		upe_name = a.upe_name,
		upe_vendor = a.upe_vendor,
		upe_model = a.upe_model,
		upe_port_status = a.upe_port_status,
		epe_name = a.epe_name,
		epe_card = a.epe_card,
		epe_slot = a.epe_slot,
		epe_port = a.epe_port,
		role = a.role,
		service_sla_slg = a.service_sla_slg,
		physical_group_slg = a.physical_group_slg,
		primary_no = a.primary_no,
        qos = a.qos,
		internet = a.internet,
		consumer_internet = a.consumer_internet,
		multimedia_data = a.multimedia_data,
		business_internet = a.business_internet,
		economy = a.economy,
		standard_data = a.standard_data,
		mission_critical = a.mission_critical,
		multimedia = a.multimedia,
		premier =a.premier,
		control =a.control,
		network_control =a.network_control,
		nbgh_plus_premier =a.nbgh_plus_premier;

	# Step 6: Archive the upe_staging data and clean it up
	INSERT INTO upe_staging_hist (
				bandwidth, 
				red_group_id, 
				upe_name, 
				upe_vendor, 
				upe_model, 
				upe_ip, 
				upe_card, 
				upe_slot, 
				upe_port, 
				upe_port_status, 
				epe_name, 
				epe_card, 
				epe_slot, 
				epe_port, 
				role, 
				product, 
				service_sla_slg, 
				physical_group_slg, 
				primary_no, 
                qos,
				internet,
				consumer_internet,
				multimedia_data,
				business_internet,
				economy,
				standard_data,
				mission_critical,
				multimedia,
				premier,
				control,
				network_control,
				nbgh_plus_premier,
				updated)
    SELECT 
				bandwidth, 
				red_group_id, 
				upe_name, 
				upe_vendor, 
				upe_model, 
				upe_ip, 
				upe_card, 
				upe_slot, 
				upe_port, 
				upe_port_status, 
				epe_name, 
				epe_card, 
				epe_slot, 
				epe_port, 
				role, 
				product, 
				service_sla_slg, 
				physical_group_slg, 
				primary_no, 
                qos,
				internet,
				consumer_internet,
				multimedia_data,
				business_internet,
				economy,
				standard_data,
				mission_critical,
				multimedia,
				premier,
				control,
				network_control,
				nbgh_plus_premier,
				updated FROM upe_staging;
    TRUNCATE TABLE upe_staging;
    
    # Step 7: Create function to delete data in upe_staging_hist after 7 days
    DELETE FROM upe_staging_hist WHERE updated < DATE_SUB(CURDATE(), INTERVAL 60 DAY);

END