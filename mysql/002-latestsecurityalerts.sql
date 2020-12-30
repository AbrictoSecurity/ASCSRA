DELIMITER $$
CREATE PROCEDURE LatestSecurityAlerts()
BEGIN
DECLARE currenttable VARCHAR(50);
SELECT TABLE_NAME INTO currenttable FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = "csra" AND TABLE_NAME LIKE "CapturedAlerts%" ORDER BY `TABLES`.`CREATE_TIME` DESC LIMIT 1;

SET @query:= CONCAT('SELECT * FROM `',currenttable, '`');
prepare stmt from @query;
execute stmt;

END $$
DELIMITER ;
