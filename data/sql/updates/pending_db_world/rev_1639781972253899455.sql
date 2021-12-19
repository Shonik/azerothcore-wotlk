INSERT INTO `version_db_world` (`sql_rev`) VALUES ('1639781972253899455');

-- Zeb'Nowa

-- Should be non moving spawns. No need to respawn just removing movement
UPDATE `creature` SET `wander_distance`=0, `MovementType`=0 WHERE `guid` IN 
(85770,85782,85803,85807,85826,85831,85867,85888,85890,85891,85892,85893,85903,85905,85907,85910,85911,85915,85924,85929,85930,85931,85789,85860,85925);
-- Respawn npcs
DELETE FROM `creature` WHERE `guid` IN 
(85762,85763,85894,85769,85771,85765,85852,85933,85866,85835,85914,85908,85922,85927,85921,85792,85869,85868,85913,85791,85790,85909,85928,85833,85774,85846,85904,85842,85781,85899,85817);
INSERT INTO `creature` (`guid`,`id`,`map`,`zoneId`,`areaId`,`spawnMask`,`phaseMask`,`modelid`,`equipment_id`,`position_x`,`position_y`,`position_z`,`orientation`,`spawntimesecs`,`wander_distance`,`currentwaypoint`,`curhealth`,`curmana`,`MovementType`,`npcflag`,`unit_flags`,`dynamicflags`,`ScriptName`,`VerifiedBuild`) VALUES
(85762, 16345, 530, 0, 0, 1, 1, 0, 0, 7149.0425, -7514.316, 47.781746, 5.8817596435546875, 300, 8, 0, 1, 0, 1, 0, 0, 0, '', 0),
(85763, 16345, 530, 0, 0, 1, 1, 0, 0, 7117.026, -7481.0166, 47.78175, 0.228037253022193908, 300, 8, 0, 1, 0, 1, 0, 0, 0, '', 0),
(85894, 16345, 530, 0, 0, 1, 1, 0, 0, 6948.322, -7447.857, 47.586338, 1.220784187316894531, 300, 8, 0, 1, 0, 1, 0, 0, 0, '', 0),
(85769, 16345, 530, 0, 0, 1, 1, 0, 0, 6985.8706, -7539.855, 61.845436, 0.049073800444602966, 300, 0, 0, 1, 0, 2, 0, 0, 0, '', 0),
(85771, 16345, 530, 0, 0, 1, 1, 0, 0, 6950.909, -7479.9644, 47.834934, 0.74932330846786499, 300, 5, 0, 1, 0, 1, 0, 0, 0, '', 0),
(85765, 16346, 530, 0, 0, 1, 1, 0, 0, 7184.8774, -7546.474, 49.156124, 2.765757322311401367, 300, 8, 0, 1, 0, 1, 0, 0, 0, '', 0),
(85922, 16346, 530, 0, 0, 1, 1, 0, 0, 6579.082, -7380.639, 58.49048, 1.545423507690429687, 300, 6, 0, 1, 0, 1, 0, 0, 0, '', 0),
(85927, 16345, 530, 0, 0, 1, 1, 0, 0, 6550.973, -7413.134, 65.63799, 2.436196565628051757, 300, 8, 0, 1, 0, 1, 0, 0, 0, '', 0),
(85921, 16346, 530, 0, 0, 1, 1, 0, 0, 6539.508, -7416.4463, 67.69685, 5.763615608215332031, 300, 0, 0, 1, 0, 2, 0, 0, 0, '', 0),
(85792, 16346, 530, 0, 0, 1, 1, 0, 0, 6586.106, -7283.4585, 52.404377, 5.954642772674560546, 300, 6, 0, 1, 0, 1, 0, 0, 0, '', 0),
(85869, 16345, 530, 0, 0, 1, 1, 0, 0, 6649.2285, -7286.7456, 52.230965, 1.878783226013183593, 300, 6, 0, 1, 0, 1, 0, 0, 0, '', 0),
(85868, 16345, 530, 0, 0, 1, 1, 0, 0, 6616.819, -7316.6025, 52.230965, 4.028967857360839843, 300, 6, 0, 1, 0, 1, 0, 0, 0, '', 0),
(85913, 16346, 530, 0, 0, 1, 1, 0, 0, 6650.9688, -7319.237, 52.230965, 2.083350658416748046, 300, 8, 0, 1, 0, 1, 0, 0, 0, '', 0),
(85791, 16345, 530, 0, 0, 1, 1, 0, 0, 6681.7285, -7318.6294, 52.230972, 0.73266458511352539, 300, 5, 0, 1, 0, 1, 0, 0, 0, '', 0),
(85790, 16345, 530, 0, 0, 1, 1, 0, 0, 6716.526, -7316.276, 52.761974, 2.011963367462158203, 300, 6, 0, 1, 0, 1, 0, 0, 0, '', 0),
(85909, 16346, 530, 0, 0, 1, 1, 0, 0, 6716.414, -7384.3403, 52.156796, 2.943116664886474609, 300, 8, 0, 1, 0, 1, 0, 0, 0, '', 0),
(85928, 16345, 530, 0, 0, 1, 1, 0, 0, 6716.23, -7351.887, 53.553314, 2.347677230834960937, 300, 8, 0, 1, 0, 1, 0, 0, 0, '', 0),
(85833, 16345, 530, 0, 0, 1, 1, 0, 0, 6749.981, -7384.8506, 51.173763, 4.45005655288696289, 300, 8, 0, 1, 0, 1, 0, 0, 0, '', 0),
(85774, 16345, 530, 0, 0, 1, 1, 0, 0, 6783.9873, -7385.604, 49.44264, 6.021385669708251953, 300, 8, 0, 1, 0, 1, 0, 0, 0, '', 0),
(85846, 16345, 530, 0, 0, 1, 1, 0, 0, 6843.5693, -7409.9473, 46.43814, 1.762953519821166992, 300, 0, 0, 1, 0, 2, 0, 0, 0, '', 0),
(85904, 16346, 530, 0, 0, 1, 1, 0, 0, 6817.987, -7348.165, 48.21628, 3.981024980545043945, 300, 6, 0, 1, 0, 1, 0, 0, 0, '', 0),
(85842, 16346, 530, 0, 0, 1, 1, 0, 0, 6848.546, -7385.6235, 46.41573, 0.771936774253845214, 300, 8, 0, 1, 0, 1, 0, 0, 0, '', 0),
(85781, 16346, 530, 0, 0, 1, 1, 0, 0, 6814.8506, -7315.854, 46.95663, 2.15785074234008789, 300, 5, 0, 1, 0, 1, 0, 0, 0, '', 0),
(85899, 16345, 530, 0, 0, 1, 1, 0, 0, 6653.56, -7406.2534, 70.74104, 1.941045880317687988, 300, 0, 0, 1, 0, 2, 0, 0, 0, '', 0),
(85852, 16345, 530, 0, 0, 1, 1, 0, 0, 6990.909, -7536.7666, 48.926872, 1.745329260826110839, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0),
(85933, 16345, 530, 0, 0, 1, 1, 0, 0, 7008.822, -7528.7197, 61.860264, 6.2657318115234375, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0),
(85835, 16346, 530, 0, 0, 1, 1, 0, 0, 7052.5693, -7520.2935, 46.250736, 4.188790321350097656, 300, 0, 0, 1, 0, 2, 0, 0, 0, '', 0),
(85914, 16346, 530, 0, 0, 1, 1, 0, 0, 7048.8906, -7484.4062, 46.575672, 5.013987064361572265, 300, 5, 0, 1, 0, 1, 0, 0, 0, '', 0),
(85908, 16346, 530, 0, 0, 1, 1, 0, 0, 7017.94, -7450.1675, 46.54, 1.466076612472534179, 300, 6, 0, 1, 0, 1, 0, 0, 0, '', 0),
(85866, 16346, 530, 0, 0, 1, 1, 0, 0, 7083.45, -7450.578, 47.69181, 4.770770072937011718, 300, 6, 0, 1, 0, 1, 0, 0, 0, '', 0),
(85817, 16346, 530, 0, 0, 1, 1, 0, 0, 7034.1763, -7541.151, 45.86117, 1.099557399749755859, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0);

-- Add missing Gameobjects to area
SET @OGUID := 9666;
DELETE FROM `gameobject` WHERE `guid` BETWEEN @OGUID+0 AND @OGUID+21;
INSERT INTO `gameobject` (`guid`,`id`,`map`,`zoneId`,`areaId`,`spawnMask`,`phaseMask`,`position_x`,`position_y`,`position_z`,`orientation`,`rotation0`,`rotation1`,`rotation2`,`rotation3`,`spawntimesecs`,`animprogress`,`state`,`VerifiedBuild`) VALUES
(@OGUID+0, 181326, 530, 3433, 3517, 1, 1, 6772.4365234375, -7350.5869140625, 48.96165847778320312, 3.141592741012573242, 0, 0, -1, 0, 120, 255, 1, 0),
(@OGUID+1, 181327, 530, 3433, 3517, 1, 1, 6610.27099609375, -7352.7568359375, 54.10820388793945312, 3.141592741012573242, 0, 0, -1, 0, 120, 255, 1, 0),
(@OGUID+2, 181329, 530, 3433, 3517, 1, 1, 7150.1875, -7558.53466796875, 47.94481277465820312, 3.141592741012573242, 0, 0, -1, 0, 120, 255, 1, 0),
(@OGUID+3, 184793, 530, 3433, 3517, 1, 1, 7159.61962890625, -7589.2724609375, 48.749053955078125, 4.223697185516357421, 0, 0, -0.85716724395751953, 0.515038192272186279, 120, 255, 1, 0),
(@OGUID+4, 184793, 530, 3433, 3517, 1, 1, 7182.4072265625, -7573.7802734375, 49.2192535400390625, 3.263772249221801757, 0, 0, -0.99813461303710937, 0.061051756143569946, 120, 255, 1, 0),
(@OGUID+5, 184793, 530, 3433, 3517, 1, 1, 7128.06787109375, -7585.1318359375, 48.81182861328125, 3.45575571060180664, 0, 0, -0.98768806457519531, 0.156436234712600708, 120, 255, 1, 0),
(@OGUID+6, 184793, 530, 3433, 3517, 1, 1, 7058.6689453125, -7545.7255859375, 45.8778839111328125, 3.78736734390258789, 0, 0, -0.94832324981689453, 0.317305892705917358, 120, 255, 1, 0),
(@OGUID+7, 184793, 530, 3433, 3517, 1, 1, 7027.02197265625, -7547.90625, 45.5196075439453125, 3.804818391799926757, 0, 0, -0.94551849365234375, 0.325568377971649169, 120, 255, 1, 0),
(@OGUID+8, 184793, 530, 3433, 3517, 1, 1, 6997.9521484375, -7518.99755859375, 56.47841644287109375, 1.256635904312133789, 0, 0, 0.587784767150878906, 0.809017360210418701, 120, 255, 1, 0),
(@OGUID+9, 184793, 530, 3433, 3517, 1, 1, 7004.17626953125, -7543.3134765625, 48.84354019165039062, 5.515241622924804687, 0, 0, -0.37460613250732421, 0.927184045314788818, 120, 255, 1, 0),
(@OGUID+10, 184793, 530, 3433, 3517, 1, 1, 6987.93896484375, -7527.7568359375, 61.78148269653320312, 5.742135047912597656, 0, 0, -0.26723766326904296, 0.96363067626953125, 120, 255, 1, 0),
(@OGUID+11, 184793, 530, 3433, 3517, 1, 1, 6996.2734375, -7547.40283203125, 48.84354019165039062, 5.009094715118408203, 0, 0, -0.59482288360595703, 0.80385679006576538, 120, 255, 1, 0),
(@OGUID+12, 184793, 530, 3433, 3517, 1, 1, 6701.36962890625, -7323.048828125, 55.5932769775390625, 2.635444164276123046, 0, 0, 0.96814727783203125, 0.250381410121917724, 120, 255, 1, 0),
(@OGUID+13, 184793, 530, 3433, 3517, 1, 1, 6698.1611328125, -7318.4140625, 55.59328079223632812, 5.777040958404541015, 0, 0, -0.25037956237792968, 0.968147754669189453, 120, 255, 1, 0),
(@OGUID+14, 184793, 530, 3433, 3517, 1, 1, 6660.8603515625, -7392.01220703125, 70.47367095947265625, 5.061456203460693359, 0, 0, -0.57357597351074218, 0.819152355194091796, 120, 255, 1, 0),
(@OGUID+15, 184793, 530, 3433, 3517, 1, 1, 6652.1787109375, -7409.3994140625, 65.2256317138671875, 5.532694816589355468, 0, 0, -0.3665008544921875, 0.93041771650314331, 120, 255, 1, 0),
(@OGUID+16, 184793, 530, 3433, 3517, 1, 1, 6645.671875, -7273.37158203125, 54.9746246337890625, 1.396261811256408691, 0, 0, 0.642786979675292968, 0.766044974327087402, 120, 255, 1, 0),
(@OGUID+17, 184793, 530, 3433, 3517, 1, 1, 6647.09033203125, -7404.20751953125, 57.55510330200195312, 3.682650327682495117, 0, 0, -0.96362972259521484, 0.26724100112915039, 120, 255, 1, 0), 
(@OGUID+18, 184793, 530, 3433, 3517, 1, 1, 6603.85693359375, -7301.5556640625, 55.20138931274414062, 2.879789113998413085, 0, 0, 0.991444587707519531, 0.130528271198272705, 120, 255, 1, 0),
(@OGUID+19, 184793, 530, 3433, 3517, 1, 1, 6524.568359375, -7412.9365234375, 69.10111236572265625, 3.595378875732421875, 0, 0, -0.97437000274658203, 0.224951311945915222, 120, 255, 1, 0),
(@OGUID+20, 184793, 530, 3433, 3517, 1, 1, 6505.11376953125, -7441.9365234375, 85.97518157958984375, 5.410521507263183593, 0, 0, -0.42261791229248046, 0.906307935714721679, 120, 255, 1, 0),
(@OGUID+21, 184793, 530, 3433, 3517, 1, 1, 6719.63916015625, -7438.46875, 51.35992431640625, 4.345870018005371093, 0, 0, -0.82412624359130859, 0.566406130790710449, 120, 255, 1, 0);

-- Pathing for Shadowpine Hexxer Entry: 16346
SET @NPC := 85835;
SET @PATH := @NPC * 10;
DELETE FROM `creature_addon` WHERE `guid`=@NPC;
INSERT INTO `creature_addon` (`guid`,`path_id`,`mount`,`bytes1`,`bytes2`,`emote`,`visibilityDistanceType`,`auras`) VALUES (@NPC,@PATH,0,0,1,0,0, '');
DELETE FROM `waypoint_data` WHERE `id`=@PATH;
INSERT INTO `waypoint_data` (`id`,`point`,`position_x`,`position_y`,`position_z`,`orientation`,`delay`,`move_type`,`action`,`action_chance`,`wpguid`) VALUES
(@PATH,1,7054.718,-7515.0557,45.825306,0,0,0,0,100,0),
(@PATH,2,7061.141,-7480.8726,47.764565,0,0,0,0,100,0),
(@PATH,3,7086.888,-7469.1978,47.879475,0,0,0,0,100,0),
(@PATH,4,7120.2534,-7478.4307,47.95727,0,0,0,0,100,0),
(@PATH,5,7158.0327,-7495.03,48.4225,0,0,0,0,100,0),
(@PATH,6,7183.4795,-7508.4634,50.49898,0,0,0,0,100,0),
(@PATH,7,7193.0874,-7526.864,48.458942,0,0,0,0,100,0),
(@PATH,8,7182.2793,-7550.2954,49.41834,0,0,0,0,100,0),
(@PATH,9,7149.923,-7553.127,48.062183,0,0,0,0,100,0),
(@PATH,10,7123.225,-7541.2754,47.774975,0,0,0,0,100,0),
(@PATH,11,7107.7764,-7519.8247,48.068493,0,0,0,0,100,0),
(@PATH,12,7078.566,-7522.566,47.673603,0,0,0,0,100,0);

-- Pathing for Shadowpine Catlord Entry: 16345
SET @NPC := 85769;
SET @PATH := @NPC * 10;
DELETE FROM `creature_addon` WHERE `guid`=@NPC;
INSERT INTO `creature_addon` (`guid`,`path_id`,`mount`,`bytes1`,`bytes2`,`emote`,`visibilityDistanceType`,`auras`) VALUES (@NPC,@PATH,0,0,1,0,0, '');
DELETE FROM `waypoint_data` WHERE `id`=@PATH;
INSERT INTO `waypoint_data` (`id`,`point`,`position_x`,`position_y`,`position_z`,`orientation`,`delay`,`move_type`,`action`,`action_chance`,`wpguid`) VALUES
(@PATH,1,6986.9443,-7539.8022,61.762104,0,0,0,0,100,0),
(@PATH,2,6981.8975,-7547.5366,61.828598,0,0,0,0,100,0),
(@PATH,3,6989.5347,-7552.494,59.415348,0,0,0,0,100,0),
(@PATH,4,6999.8955,-7552.047,56.289364,0,0,0,0,100,0),
(@PATH,5,6996.5024,-7538.8804,56.36908,0,0,0,0,100,0),
(@PATH,6,7002.2637,-7533.8735,53.50038,0,0,0,0,100,0),
(@PATH,7,7002.2153,-7528.097,49.745186,0,0,0,0,100,0),
(@PATH,8,6992.9907,-7522.231,48.843533,0,0,0,0,100,0),
(@PATH,9,6987.096,-7510.2363,48.836372,0,0,0,0,100,0),
(@PATH,10,6983.7993,-7495.7407,45.747772,0,0,0,0,100,0),
(@PATH,11,6972.151,-7467.0103,47.04904,0,0,0,0,100,0),
(@PATH,12,6981.916,-7440.968,47.308613,0,0,0,0,100,0),
(@PATH,13,6972.1235,-7466.882,47.04904,0,0,0,0,100,0),
(@PATH,14,6986.2056,-7490.85,46.084442,0,0,0,0,100,0),
(@PATH,15,7021.828,-7503.566,45.899353,0,0,0,0,100,0),
(@PATH,16,7049.295,-7519.1597,45.85497,0,0,0,0,100,0),
(@PATH,17,7021.828,-7503.566,45.899353,0,0,0,0,100,0),
(@PATH,18,6986.2056,-7490.85,46.084442,0,0,0,0,100,0),
(@PATH,19,6972.1235,-7466.882,47.04904,0,0,0,0,100,0),
(@PATH,20,6981.916,-7440.968,47.308613,0,0,0,0,100,0),
(@PATH,21,6972.151,-7467.0103,47.04904,0,0,0,0,100,0),
(@PATH,22,6983.7993,-7495.7407,45.747772,0,0,0,0,100,0),
(@PATH,23,6987.096,-7510.2363,48.836372,0,0,0,0,100,0),
(@PATH,24,6992.9907,-7522.231,48.843533,0,0,0,0,100,0),
(@PATH,25,7002.2153,-7528.097,49.745186,0,0,0,0,100,0),
(@PATH,26,7002.2637,-7533.8735,53.50038,0,0,0,0,100,0),
(@PATH,27,6996.5024,-7538.8804,56.36908,0,0,0,0,100,0),
(@PATH,28,6999.8955,-7552.047,56.289364,0,0,0,0,100,0),
(@PATH,29,6989.5347,-7552.494,59.415348,0,0,0,0,100,0),
(@PATH,30,6981.8975,-7547.5366,61.828598,0,0,0,0,100,0);

-- Pathing for Shadowpine Hexxer Entry: 16346
SET @NPC := 85921;
SET @PATH := @NPC * 10;
DELETE FROM `creature_addon` WHERE `guid`=@NPC;
INSERT INTO `creature_addon` (`guid`,`path_id`,`mount`,`bytes1`,`bytes2`,`emote`,`visibilityDistanceType`,`auras`) VALUES (@NPC,@PATH,0,0,1,0,0, '');
DELETE FROM `waypoint_data` WHERE `id`=@PATH;
INSERT INTO `waypoint_data` (`id`,`point`,`position_x`,`position_y`,`position_z`,`orientation`,`delay`,`move_type`,`action`,`action_chance`,`wpguid`) VALUES
(@PATH,1,6542.071,-7417.913,67.300964,0,0,0,0,100,0),
(@PATH,2,6558.9907,-7396.349,61.79305,0,0,0,0,100,0),
(@PATH,3,6584.4653,-7368.2153,56.645763,0,0,0,0,100,0),
(@PATH,4,6598.5337,-7348.974,54.28678,0,0,0,0,100,0),
(@PATH,5,6615.359,-7339.764,53.562553,0,0,0,0,100,0),
(@PATH,6,6647.1865,-7348.8647,53.182693,0,0,0,0,100,0),
(@PATH,7,6682.1904,-7368.343,54.08907,0,0,0,0,100,0),
(@PATH,8,6703.269,-7370.278,53.048145,0,0,0,0,100,0),
(@PATH,9,6728.651,-7395.8916,51.548145,0,0,0,0,100,0),
(@PATH,10,6753.0396,-7417.468,51.447056,0,0,0,0,100,0),
(@PATH,11,6728.651,-7395.8916,51.548145,0,0,0,0,100,0),
(@PATH,12,6703.269,-7370.278,53.048145,0,0,0,0,100,0),
(@PATH,13,6682.1904,-7368.343,54.08907,0,0,0,0,100,0),
(@PATH,14,6647.1865,-7348.8647,53.182693,0,0,0,0,100,0),
(@PATH,15,6615.359,-7339.764,53.562553,0,0,0,0,100,0),
(@PATH,16,6598.5337,-7348.974,54.28678,0,0,0,0,100,0),
(@PATH,17,6584.4653,-7368.2153,56.645763,0,0,0,0,100,0),
(@PATH,18,6558.9907,-7396.349,61.79305,0,0,0,0,100,0);

-- Pathing for Shadowpine Catlord Entry: 16345
SET @NPC := 85846;
SET @PATH := @NPC * 10;
DELETE FROM `creature_addon` WHERE `guid`=@NPC;
INSERT INTO `creature_addon` (`guid`,`path_id`,`mount`,`bytes1`,`bytes2`,`emote`,`visibilityDistanceType`,`auras`) VALUES (@NPC,@PATH,0,0,1,0,0, '');
DELETE FROM `waypoint_data` WHERE `id`=@PATH;
INSERT INTO `waypoint_data` (`id`,`point`,`position_x`,`position_y`,`position_z`,`orientation`,`delay`,`move_type`,`action`,`action_chance`,`wpguid`) VALUES
(@PATH,1,6843.4995,-7409.5884,46.4158,0,0,0,0,100,0),
(@PATH,2,6816.644,-7407.396,48.21939,0,0,0,0,100,0),
(@PATH,3,6790.0303,-7391.276,47.954563,0,0,0,0,100,0),
(@PATH,4,6775.2866,-7359.6704,49.270485,0,0,0,0,100,0),
(@PATH,5,6760.4487,-7356.145,48.84367,0,0,0,0,100,0),
(@PATH,6,6736.911,-7385.6084,51.535816,0,0,0,0,100,0),
(@PATH,7,6706.3916,-7408.4707,51.19869,0,0,0,0,100,0),
(@PATH,8,6736.911,-7385.6084,51.535816,0,0,0,0,100,0),
(@PATH,9,6760.4487,-7356.145,48.84367,0,0,0,0,100,0),
(@PATH,10,6775.2866,-7359.6704,49.270485,0,0,0,0,100,0),
(@PATH,11,6790.0303,-7391.276,47.954563,0,0,0,0,100,0),
(@PATH,12,6816.644,-7407.396,48.21939,0,0,0,0,100,0);

-- Pathing for Shadowpine Catlord Entry: 16345
SET @NPC := 85899;
SET @PATH := @NPC * 10;
DELETE FROM `creature_addon` WHERE `guid`=@NPC;
INSERT INTO `creature_addon` (`guid`,`path_id`,`mount`,`bytes1`,`bytes2`,`emote`,`visibilityDistanceType`,`auras`) VALUES (@NPC,@PATH,0,0,1,0,0, '');
DELETE FROM `waypoint_data` WHERE `id`=@PATH;
INSERT INTO `waypoint_data` (`id`,`point`,`position_x`,`position_y`,`position_z`,`orientation`,`delay`,`move_type`,`action`,`action_chance`,`wpguid`) VALUES
(@PATH,1,6653.061,-7404.968,70.65209,0,0,0,0,100,0),
(@PATH,2,6652.2246,-7392.04,70.47367,0,0,0,0,100,0),
(@PATH,3,6645.2124,-7388.8613,70.538475,0,0,0,0,100,0),
(@PATH,4,6641.3394,-7398.835,67.97912,0,0,0,0,100,0),
(@PATH,5,6643.684,-7409.694,65.00207,0,0,0,0,100,0),
(@PATH,6,6656.348,-7402.172,65.17447,0,0,0,0,100,0),
(@PATH,7,6660.9976,-7406.9395,62.68082,0,0,0,0,100,0),
(@PATH,8,6667.743,-7405.6895,58.3103,0,0,0,0,100,0),
(@PATH,9,6674.52,-7392.116,57.555096,0,0,0,0,100,0),
(@PATH,10,6686.4956,-7386.0522,57.543495,0,0,0,0,100,0),
(@PATH,11,6701.096,-7375.452,52.987476,0,0,0,0,100,0),
(@PATH,12,6713.9585,-7335.453,52.834385,0,0,0,0,100,0),
(@PATH,13,6705.33,-7304.4565,51.288025,0,0,0,0,100,0),
(@PATH,14,6667.696,-7315.061,52.243465,0,0,0,0,100,0),
(@PATH,15,6656.711,-7350.3984,53.881424,0,0,0,0,100,0),
(@PATH,16,6671.56,-7365.549,55.219166,0,0,0,0,100,0),
(@PATH,17,6701.157,-7375.5767,52.965137,0,0,0,0,100,0),
(@PATH,18,6686.545,-7386.2075,57.543495,0,0,0,0,100,0),
(@PATH,19,6674.511,-7391.9287,57.555096,0,0,0,0,100,0),
(@PATH,20,6667.743,-7405.6895,58.3103,0,0,0,0,100,0),
(@PATH,21,6660.9976,-7406.9395,62.68082,0,0,0,0,100,0),
(@PATH,22,6656.4673,-7402.0835,65.12421,0,0,0,0,100,0),
(@PATH,23,6643.684,-7409.694,65.00207,0,0,0,0,100,0),
(@PATH,24,6641.3306,-7398.935,67.93379,0,0,0,0,100,0),
(@PATH,25,6645.2144,-7388.875,70.53829,0,0,0,0,100,0),
(@PATH,26,6652.309,-7391.9766,70.47367,0,0,0,0,100,0),
(@PATH,27,6662.7456,-7386.941,70.47937,0,0,0,0,100,0),
(@PATH,28,6672.8364,-7390.348,70.596016,0,0,0,0,100,0),
(@PATH,29,6674.759,-7402.2993,70.481064,0,0,0,0,100,0),
(@PATH,30,6665.353,-7409.6694,70.42119,0,0,0,0,100,0);
