CREATE DEFINER=`admin_user`@`%` PROCEDURE `proc_customer_profile`()
BEGIN
	# Process data from customer_profile_daily to customer_profile_main. Must be performed before proc_epe
    
	## For the sake of testing
    DECLARE affectedRow INT;
    DECLARE occurrences INT;
    
    # tmp_upe_staging = tmp_customer_profile_daily
    # tmp_upe_main = tmp_customer_profile_main
    # upe_staging = customer_profile_daily
    
    # Step 0: Send to customer_profile_daily_hist
    INSERT INTO customer_profile_daily_hist (
				service_id,
				status,
				installation_date,
				billing_account,
				billing_account_address,
				billing_account_no,
				customer_account,
				product,
				commercial_slg,
				installation_address,
				updated
				) SELECT 
				service_id,
				status,
				installation_date,
				billing_account,
				billing_account_address,
				billing_account_no,
				customer_account,
				product,
				commercial_slg,
				installation_address,
				updated
				FROM  customer_profile_daily;
    
	# Step 1: Prepare
    TRUNCATE TABLE tmp_customer_profile_daily;
    TRUNCATE TABLE tmp_customer_profile_main;
    INSERT INTO tmp_customer_profile_daily SELECT * FROM customer_profile_daily;
    
    # Step 2: Clean up
    
    # Error Type 1 (DELETE)
    DELETE FROM tmp_customer_profile_daily WHERE service_id = '' or service_id is null;
    SET affectedRow = (SELECT ROW_COUNT());
    if affectedRow > 0 then
		INSERT INTO metroe_error(table_name, remarks, occurrences) VALUE('customer_profile_daily', 'Empty service_id', affectedRow);
	end if;
    
	# Error Type 2 (NOT DELETE)
    SET occurrences = (SELECT count(*) FROM tmp_customer_profile_daily WHERE commercial_slg = '' or commercial_slg is null);
    SET affectedRow = (SELECT ROW_COUNT());
    if affectedRow > 0 then
		INSERT INTO metroe_error(table_name, remarks, occurrences) VALUE('customer_profile_daily', 'Empty commercial_slg', affectedRow);
	end if;
    
	# Error Type 3 (DELETE)
    DELETE FROM tmp_customer_profile_daily WHERE status <> 'ACTIVE' or length(service_id) > 12;
    SET affectedRow = (SELECT ROW_COUNT());
    if affectedRow > 0 then
		INSERT INTO metroe_error(table_name, remarks, occurrences) VALUE('customer_profile_daily', 'INACTIVE status and length(service_id) > 12', affectedRow);
	end if;
    
	# Error Type 4 (NOT DELETE)
    SET occurrences = (SELECT count(*) FROM metroe.customer_profile_daily where billing_account_no is null or billing_account_no='' or billing_account_no=0);
    SET affectedRow = (SELECT ROW_COUNT());
    if affectedRow > 0 then
		INSERT INTO metroe_error(table_name, remarks, occurrences) VALUE('customer_profile_daily', 'Empty billing_account_no', affectedRow);
	end if;
    
	# Error Type 5 (NOT DELETE)
    SET occurrences = (SELECT count(*) FROM metroe.customer_profile_daily where customer_account is null or customer_account='');
    SET affectedRow = (SELECT ROW_COUNT());
    if affectedRow > 0 then
		INSERT INTO metroe_error(table_name, remarks, occurrences) VALUE('customer_profile_daily', 'Empty customer_account', affectedRow);
	end if;
    
	# Error Type 6 (DELETE)
    SET occurrences = (SELECT count(*) FROM metroe.customer_profile_daily where status not in ('Inactive','Active'));
    SET affectedRow = (SELECT ROW_COUNT());
    if affectedRow > 0 then
		INSERT INTO metroe_error(table_name, remarks, occurrences) VALUE('customer_profile_daily', 'Status is not Active or Inactive', affectedRow);
	end if;
    
    # Step 4: Populate tmp_customer_profile_main
    INSERT INTO tmp_customer_profile_main (
				service_id,
				status,
				installation_date,
				billing_account,
				billing_account_address,
				billing_account_no,
				customer_account,
				product,
				commercial_slg,
				installation_address,
				updated,
                customer_ref_id) 
    SELECT 
				service_id,
				status,
				installation_date,
				billing_account,
				billing_account_address,
				billing_account_no,
				customer_account,
				product,
				commercial_slg,
				installation_address,
				updated,
                concat_ws('',service_id,'_',billing_account_no) as customer_ref_id FROM tmp_customer_profile_daily group by customer_ref_id;

    # Step 5: Populate the customer_profile_main
	INSERT INTO customer_profile_main (
				service_id,
				status,
				installation_date,
				billing_account,
				billing_account_address,
				billing_account_no,
				customer_account,
				product,
				commercial_slg,
				installation_address,
                updated,
                customer_ref_id) 
      SELECT 
				service_id,
				status,
				installation_date,
				billing_account,
				billing_account_address,
				billing_account_no,
				customer_account,
				product,
				commercial_slg,
				installation_address,
                updated,
                customer_ref_id
      FROM tmp_customer_profile_main AS a
      ON DUPLICATE KEY UPDATE 
		service_id = a.service_id, 
        status = a.status,
		installation_date = a.installation_date,
		billing_account = a.billing_account,
		billing_account_address = a.billing_account_address,
		billing_account_no = a.billing_account_no,
		customer_account = a.customer_account,
		product = a.product,
		commercial_slg = a.commercial_slg,
		installation_address = a.installation_address,
        updated = a.updated,
        customer_ref_id =a.customer_ref_id;

    # TRUNCATE TABLE customer_profile_daily;
    
    # Step 7: Create function to delete data in upe_staging_hist after 7 days
    DELETE FROM customer_profile_daily_hist WHERE updated < DATE_SUB(CURDATE(), INTERVAL 7 DAY);

END