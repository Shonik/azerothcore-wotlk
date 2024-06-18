-- Archmage Xylem
DELETE FROM `creature` WHERE (`id1` = 8379);
INSERT INTO `creature` (`guid`, `id1`, `id2`, `id3`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `equipment_id`, `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, `wander_distance`, `currentwaypoint`, `curhealth`, `curmana`, `MovementType`, `npcflag`, `unit_flags`, `dynamicflags`, `ScriptName`, `VerifiedBuild`, `CreateObject`, `Comment`) VALUES
(35886, 8379, 0, 0, 1, 0, 0, 1, 1, 0, 3982.08, -4760.25, 304.8, 0.347593, 333, 0, 0, 2884, 5751, 2, 0, 0, 0, '', 0, 0, NULL);

UPDATE `creature_addon` SET `path_id` = 3588600 WHERE `guid` = 35886;

DELETE FROM `waypoint_data` WHERE `id` = 3588600;
INSERT INTO `waypoint_data` (`id`, `point`, `position_x`, `position_y`, `position_z`, `orientation`, `delay`, `move_type`, `action`, `action_chance`, `wpguid`) VALUES
(3588600, 1, 3982.08, -4760.25, 304.803,  5.3781, 60000, 0, 0, 100, 0),
(3588600, 2, 3975.94, -4767.85, 304.728,  100, 0, 0, 0, 100, 0),
(3588600, 3, 3972.76, -4771.82, 304.716,  100, 0, 0, 0, 100, 0),
(3588600, 4, 3970.95, -4777.04, 304.728,  100, 0, 0, 0, 100, 0),
(3588600, 5, 3970.78, -4780.04, 304.712,  100, 0, 0, 0, 100, 0),
(3588600, 6, 3971.65, -4784.84, 304.718,  100, 0, 0, 0, 100, 0),
(3588600, 7, 3976.24, -4788.04, 304.717,  100, 0, 0, 0, 100, 0),
(3588600, 8, 3977.89, -4786.99, 304.73,   100, 0, 0, 0, 100, 0),
(3588600, 9, 3977.45, -4783.41, 303.731,  100, 0, 0, 0, 100, 0),
(3588600, 10, 3979.76, -4780.78, 301.995, 100, 0, 0, 0, 100, 0),
(3588600, 11, 3983.23, -4782.2, 299.606,  100, 0, 0, 0, 100, 0),
(3588600, 12, 3982.05, -4785.25, 297.913, 100, 0, 0, 0, 100, 0),
(3588600, 13, 3974.91, -4782.9, 295.922,  100, 0, 0, 0, 100, 0),
(3588600, 14, 3969.92, -4784.16, 296.018, 100, 10000, 0, 0, 100, 0),
(3588600, 15, 3974.91, -4782.9, 295.922,  100, 0, 0, 0, 100, 0),
(3588600, 16, 3982.05, -4785.25, 297.913, 100, 0, 0, 0, 100, 0),
(3588600, 17, 3983.23, -4782.2, 299.606,  100, 0, 0, 0, 100, 0),
(3588600, 18, 3979.76, -4780.78, 301.995, 100, 0, 0, 0, 100, 0),
(3588600, 19, 3977.45, -4783.41, 303.731, 100, 0, 0, 0, 100, 0),
(3588600, 20, 3977.89, -4786.99, 304.73,  100, 0, 0, 0, 100, 0),
(3588600, 21, 3976.24, -4788.04, 304.717, 100, 0, 0, 0, 100, 0),
(3588600, 22, 3971.65, -4784.84, 304.718, 100, 0, 0, 0, 100, 0),
(3588600, 23, 3970.78, -4780.04, 304.712, 100, 0, 0, 0, 100, 0),
(3588600, 24, 3970.95, -4777.04, 304.728, 100, 0, 0, 0, 100, 0),
(3588600, 25, 3972.76, -4771.82, 304.716, 100, 0, 0, 0, 100, 0),
(3588600, 26, 3975.94, -4767.85, 304.728, 100, 0, 0, 0, 100, 0);
