CREATE DEFINER=`admin_user`@`%` PROCEDURE `proc_flash`()
BEGIN
	# Purpose: Process the flash_staging to flash_main
    DECLARE occurrences INT;
    
    # Step 1: Prepare for processing
    DELETE FROM tmp_flash_staging;
    DELETE FROM tmp_flash_main;
    INSERT INTO tmp_flash_staging SELECT * FROM flash_staging;
    
    # Step 2: Clean up
	# Error Type 1
    SET occurrences = (SELECT COUNT(*) FROM tmp_flash_staging WHERE ne_shelf NOT REGEXP '^-?[0-9]+$');
    if occurrences > 0 then
		INSERT INTO metroe_error(table_name, remarks, occurrences) VALUE('flash_staging', 'ne_shelf is not an integer', occurrences);
    end if;
    
	SET occurrences = (SELECT COUNT(*) FROM tmp_flash_staging WHERE ne_slot NOT REGEXP '^-?[0-9]+$');
    if occurrences > 0 then
		INSERT INTO metroe_error(table_name, remarks, occurrences) VALUE('flash_staging', 'ne_slot is not an integer', occurrences);
    end if;
    
	SET occurrences = (SELECT COUNT(*) FROM tmp_flash_staging WHERE ne_port NOT REGEXP '^-?[0-9]+$');
    if occurrences > 0 then
		INSERT INTO metroe_error(table_name, remarks, occurrences) VALUE('flash_staging', 'ne_port is not an integer', occurrences);
    end if;
    
    # Error Type 2
	SET occurrences = (SELECT COUNT(*) FROM tmp_flash_staging WHERE ne_shelf IN ('', '?'));
    if occurrences > 0 then
		INSERT INTO metroe_error(table_name, remarks, occurrences) VALUE('flash_staging', 'ne_shelf is empty or ?', occurrences);
    end if;
    
	SET occurrences = (SELECT COUNT(*) FROM tmp_flash_staging WHERE ne_slot IN ('', '?'));
    if occurrences > 0 then
		INSERT INTO metroe_error(table_name, remarks, occurrences) VALUE('flash_staging', 'ne_slot is empty or ?', occurrences);
    end if;
    
	SET occurrences = (SELECT COUNT(*) FROM tmp_flash_staging WHERE ne_port IN ('', '?'));
    if occurrences > 0 then
		INSERT INTO metroe_error(table_name, remarks, occurrences) VALUE('flash_staging', 'ne_port is empty or ?', occurrences);
    end if;
    
    # Remarks: We update it here so that we can identify first how many is having issue
    UPDATE tmp_flash_staging SET ne_shelf = NULL WHERE ne_shelf NOT REGEXP '^-?[0-9]+$';
    UPDATE tmp_flash_staging SET ne_slot = NULL WHERE ne_slot NOT REGEXP '^-?[0-9]+$';
	UPDATE tmp_flash_staging SET ne_shelf = NULL WHERE ne_port NOT REGEXP '^-?[0-9]+$';
    
	DELETE FROM tmp_flash_staging WHERE ne_shelf IN (null, '', '?');
    DELETE FROM tmp_flash_staging WHERE ne_slot IN (null, '', '?');
    DELETE FROM tmp_flash_staging WHERE ne_port IN (null, '', '?');
    
    # Step 3: Copy the right data
	INSERT INTO tmp_flash_main (cable_name,type,core_no,core_status,frame_name,frame_location,shelf_block,row_no,vertical,ne_id,ne_shelf,ne_slot,ne_port,frame_name2,frame_location2,shelf_block2,row_no2,vertical2,access_port,ne_id2,updated,flash_id) SELECT cable_name,type,core_no,core_status,frame_name,frame_location,shelf_block,row_no,vertical,ne_id,ne_shelf,ne_slot,ne_port,frame_name2,frame_location2,shelf_block2,row_no2,vertical2,access_port,ne_id2,updated, concat_ws('',ne_id,'_',ne_shelf,'/',ne_slot,'/',ne_port,'_',core_no) as flash_id FROM tmp_flash_staging WHERE ne_id IN (SELECT epe_name FROM epe_main) group by flash_id;
    
    # Step 4: Will all ok so far, time to transfer to the main table on duplicates update
    INSERT INTO flash_main (cable_name,
                                type,
                                core_no,
                                core_status,
                                frame_name,
                                frame_location,
                                shelf_block,
                                row_no,
                                vertical,
                                ne_id,
                                ne_shelf,
                                ne_slot,
                                ne_port,
                                frame_name2,
                                frame_location2,
                                shelf_block2,
                                row_no2,
                                vertical2,
                                access_port,
                                ne_id2,
                                flash_id)
                            SELECT 
                                cable_name,
                                type,
                                core_no,
                                core_status,
                                frame_name,
                                frame_location,
                                shelf_block,
                                row_no,
                                vertical,
                                ne_id,
                                ne_shelf,
                                ne_slot,
                                ne_port,
                                frame_name2,
                                frame_location2,
                                shelf_block2,
                                row_no2,
                                vertical2,
                                access_port,
                                ne_id2,
                                flash_id
                            FROM tmp_flash_main AS a
                            ON DUPLICATE KEY UPDATE
                                cable_name = a.cable_name,
                                type = a.type,
                                core_no = a.core_no,
                                core_status = a.core_status,
                                frame_name = a.frame_name,
                                frame_location = a.frame_location,
                                shelf_block = a.shelf_block,
                                row_no = a.row_no,
                                vertical = a.vertical,
                                ne_id = a.ne_id,
                                ne_shelf = a.ne_shelf,
                                ne_slot = a.ne_slot,
                                ne_port = a.ne_port,
                                frame_name2 = a.frame_name2,
                                frame_location2 = a.frame_location2,
                                shelf_block2 = a.shelf_block2,
                                row_no2 = a.row_no2,
                                vertical2 = a.vertical2,
                                access_port = a.access_port,
                                ne_id2 = a.ne_id2,
                                flash_id = a.flash_id;


    # Step 6: Archive the flash_staging data and clean it up
    INSERT INTO flash_staging_hist (cable_name, type, core_no, core_status, frame_name, frame_location, shelf_block, row_no, vertical, ne_id, ne_shelf, ne_slot, ne_port, frame_name2, frame_location2, shelf_block2, row_no2, vertical2, access_port, ne_id2, updated) SELECT cable_name, type, core_no, core_status, frame_name, frame_location, shelf_block, row_no, vertical, ne_id, ne_shelf, ne_slot, ne_port, frame_name2, frame_location2, shelf_block2, row_no2, vertical2, access_port, ne_id2, updated FROM flash_staging;
    TRUNCATE TABLE flash_staging;
    
	# Step 7: Create function to delete data in flash_staging_hist after 28 days
    DELETE FROM flash_staging_hist WHERE updated < DATE_SUB(CURDATE(), INTERVAL 28 DAY);
END