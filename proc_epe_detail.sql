CREATE DEFINER=`admin_user`@`%` PROCEDURE `proc_epe_detail`()
BEGIN
	## Step 0 - Insert into epe_detail_hist 
    INSERT INTO epe_detail_hist (
								bandwidth,
								red_group_id,
								upe_name,
								upe_vendor,
								upe_model,
								upe_port_status,
								epe_name,
								epe_vendor,
								epe_model,
								epe_card,
								epe_slot,
								epe_port,
								role,
                                commercial_slg,
								service_sla_slg,
								physical_group_slg,
								primary_no,
								customer_account,
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
								epe_serial,
								epe_ip,
								epe_status,
								cable_name,
								core_no,
								exc_abb,
								zone_code,
								wilayah_code,
								region_code,
								faulty,
								remark_code,
                                remark,
								updated) SELECT 
                                bandwidth,
                                red_group_id,
								upe_name,
								upe_vendor,
								upe_model,
								upe_port_status,
								epe_name,
								epe_vendor,
								epe_model,
								epe_card,
								epe_slot,
								epe_port,
								role,
								commercial_slg,
								service_sla_slg,
								physical_group_slg,
								primary_no,
                                customer_account,
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
								epe_serial,
								epe_ip,
								epe_status,
								cable_name,
								core_no,
								exc_abb,
								zone_code,
								wilayah_code,
								region_code,
								faulty,
								remark_code,
                                remark,
								updated from epe_detail;

	## Step 1 - Prepare tmp tables
    TRUNCATE TABLE tmp_upe_main;
    TRUNCATE TABLE tmp_epe_detail;
    INSERT INTO tmp_upe_main SELECT * FROM upe_main WHERE epe_name IN (SELECT epe_name FROM epe_main);
    
    ## Step 2 - Populate the raw epe_detail
    INSERT INTO tmp_epe_detail(
			bandwidth,
			red_group_id, 	
			upe_name, 
			upe_vendor, 
			upe_model, 
			upe_port_status, 
			epe_name, 
			epe_vendor, 
			epe_model, 
			epe_card, 
			epe_slot, 
			epe_port, 
			role, 
            commercial_slg,
			service_sla_slg, 
			physical_group_slg, 
			primary_no, 
            customer_account,
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
			epe_serial, 
			epe_ip, 
			epe_status, 
			cable_name, 
			core_no, 
			exc_abb, 
			zone_code, 
			wilayah_code, 
			region_code)
	SELECT 
			a.bandwidth,
			a.red_group_id, 
            a.upe_name, 
            a.upe_vendor, 
            a.upe_model,
            a.upe_port_status,
            a.epe_name,
			b.vendor,
            b.model_eq,
            a.epe_card,
            a.epe_slot,
            a.epe_port,
            a.role,
            e.commercial_slg,
            a.service_sla_slg,
            a.physical_group_slg,
            a.primary_no,
            e.customer_account,
            a.qos,
			a.internet,
			a.consumer_internet,
			a.multimedia_data,
			a.business_internet,
			a.economy,
			a.standard_data,
			a.mission_critical,
			a.multimedia,
			a.premier,
			a.control,
			a.network_control,
			a.nbgh_plus_premier,
            b.serial,
            b.ip,
            b.status,
            d.cable_name,
            d.core_no,
            b.exc,
            c.zone_code,
            c.wilayah_code,
            c.region_code
		FROM tmp_upe_main AS a
		JOIN epe_main AS b ON b.epe_name = a.epe_name
		LEFT JOIN (select group_concat(distinct cable_name) as cable_name, group_concat(distinct core_no) as core_no ,ne_id, ne_shelf ,ne_slot ,ne_port
		from flash_main group by ne_id, ne_shelf ,ne_slot ,ne_port) AS d 
        ON a.epe_name = d.ne_id AND a.epe_card = d.ne_shelf AND a.epe_slot = d.ne_slot AND a.epe_port = d.ne_port
        LEFT JOIN (select service_id, customer_account as customer_account, commercial_slg as commercial_slg from customer_profile_main group by service_id) AS e 
        ON a.red_group_id = e.service_id        
        LEFT JOIN inv_detail AS c ON c.exc = b.exc;
        -- LEFT JOIN flash_main AS d ON a.epe_name = d.ne_id AND a.epe_card = d.ne_shelf AND a.epe_slot = d.ne_slot AND a.epe_port = d.ne_port
        -- LEFT JOIN inv_detail AS c ON c.exc = b.exc;
        
	## Step 3 - Set the faulty flag and remarks code
    # Case for unknown EPE
    UPDATE tmp_epe_detail SET faulty = '1', remark_code = 'REMM-IVDB-01474', remark = 'EPE/NPE info not available from GRANITE' WHERE epe_name NOT IN (SELECT epe_name FROM epe_main);
    
    # Case for epe_ip NULL (REMM-IVDB-01478)
    UPDATE tmp_epe_detail SET faulty = '1', remark_code = 'REMM-IVDB-01478', remark = 'IP address EPE/NPE not available from Granite' WHERE epe_ip IS NULL;
    
    # Case for epe_card IS NULL (REMM-IVDB-01479)
    UPDATE tmp_epe_detail SET faulty = '1', remark_code = 'REMM-IVDB-01479', remark = 'EPE/NPE card not available from Granite' WHERE epe_card IS NULL;
    
    # Case for epe_slot IS NULL (REMM-IVDB-01480)
    UPDATE tmp_epe_detail SET faulty = '1', remark_code = 'REMM-IVDB-01480', remark = 'EPE/NPE slot not available from Granite' WHERE epe_slot IS NULL;
    
    # Case for epe_port IS NULL (REMM-IVDB-01481)
    UPDATE tmp_epe_detail SET faulty = '1', remark_code = 'REMM-IVDB-01481', remark = 'EPE/NPE port not available from Granite' WHERE epe_port IS NULL;
    
    # Case for role is NULL (REMM-IVDB-01482)
    # UPDATE tmp_epe_detail SET faulty = '1', remark_code = 'REMM-IVDB-01482', remark = 'EPE/NPE role not available from Granite' WHERE role IS NULL;
    
	# Case for epe_card > 30 (REMM-IVDB-01487)
    UPDATE tmp_epe_detail SET faulty = '1', remark_code = 'REMM-IVDB-01487', remark = 'EPE/NPE card not available from Granite' WHERE epe_card > 30;
    
	# Case for epe_card is NULL (REMM-IVDB-01488)
    UPDATE tmp_epe_detail SET faulty = '1', remark_code = 'REMM-IVDB-01488', remark = 'EPE/NPE card not available from Granite' WHERE epe_card is null;
    
    # Update case null = 0
    UPDATE tmp_epe_detail set faulty = '0' where remark_code is null;
    UPDATE tmp_epe_detail set remark_code = '' where remark_code is null;
    UPDATE tmp_epe_detail set remark = '' where remark is null;
    
    
    ## Step 4 - For the time being, copy everything to the epe_detail table
    # perhaps in the future we shall revisit to have it updated on deplicate
    TRUNCATE TABLE epe_detail;
    INSERT INTO epe_detail SELECT * FROM tmp_epe_detail;
    
END