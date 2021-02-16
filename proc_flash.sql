CREATE DEFINER=`admin_user`@`%` PROCEDURE `proc_flash`()
BEGIN
	# Purpose: Process the flash_staging to flash_main
    
    # Step 1: Prepare for processing
    DELETE FROM tmp_flash_staging;
    DELETE FROM tmp_flash_main;
    INSERT INTO tmp_flash_staging SELECT * FROM flash_staging;
    
    # Step 2: Clean up
	DELETE FROM tmp_flash_staging WHERE ne_shelf IN ('', '?');
    DELETE FROM tmp_flash_staging WHERE ne_slot IN ('', '?');
    DELETE FROM tmp_flash_staging WHERE ne_port IN ('', '?');
    
    # Step 3: Copy the right data
	INSERT INTO tmp_flash_main (cable_name,type,core_no,core_status,frame_name,frame_location,shelf_block,row_no,vertical,ne_id,ne_shelf,ne_slot,ne_port,frame_name2,frame_location2,shelf_block2,row_no2,vertical2,access_port,ne_id2,updated,flash_id) SELECT cable_name,type,core_no,core_status,frame_name,frame_location,shelf_block,row_no,vertical,ne_id,ne_shelf,ne_slot,ne_port,frame_name2,frame_location2,shelf_block2,row_no2,vertical2,access_port,ne_id2,updated, concat_ws('',ne_id,'_',ne_shelf,'/',ne_slot,'/',ne_port) as flash_id FROM tmp_flash_staging WHERE ne_id IN (SELECT epe_name FROM epe_main);
    
    # Step 4: Will all ok so far, time to transfer to the main table
    DELETE FROM flash_main;
    INSERT INTO flash_main SELECT * FROM tmp_flash_main;
END