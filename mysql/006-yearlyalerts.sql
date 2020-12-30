DELIMITER $$
CREATE PROCEDURE YearlyAlerts()
BEGIN
SELECT CREATE_TIME,TABLE_ROWS FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = "csra" AND TABLE_NAME LIKE "CapturedAlerts%" AND CREATE_TIME > NOW() - INTERVAL 1 YEAR;

END $$
DELIMITER ;
