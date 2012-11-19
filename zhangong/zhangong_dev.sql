BEGIN TRANSACTION;
CREATE TABLE "gongxun"([level] int(11) NOT NULL,[name] varchar(20) NOT NULL,[score] int(11) NOT NULL,[category] varchar(10) NOT NULL, Primary Key(level,category) ON CONFLICT Ignore);
CREATE TABLE "skills"([skillname] varchar(20) NOT NULL,[gained] int(11) NOT NULL,[used] int(11) NOT NULL, Primary Key(skillname) ON CONFLICT Ignore);
CREATE TABLE "gamedata"([id] varchar(20) NOT NULL,[num] int(11) NOT NULL, Primary Key(id) ON CONFLICT Ignore);
CREATE TABLE "zhangong"([id] varchar(10) NOT NULL,[name] varchar(30) NOT NULL,[score] int(11) NOT NULL,[description] varchar(250) NOT NULL,[gained] int(11) NOT NULL,[category] varchar(20) NOT NULL,[lasttime] datetime NOT NULL,[general] varchar(40) NOT NULL,[num] int(11) NOT NULL,[count] int(11) NOT NULL, Primary Key(id) ON CONFLICT Ignore);
CREATE TABLE "results"([id] int(11) NOT NULL,[general] varchar(30) NOT NULL,[role] varchar(10) NOT NULL,[kingdom] varchar(10) NOT NULL,[hegemony] int(11) NOT NULL,[mode] varchar(10) NOT NULL,[turncount] int(11) NOT NULL,[alive] int(11) NOT NULL,[result] varchar(10) NOT NULL,[wen] int(11) NOT NULL,[wu] int(11) NOT NULL,[expval] int(11) NOT NULL,[zhangong] varchar(255) NOT NULL, Primary Key(id) ON CONFLICT Ignore);
CREATE INDEX [gamedata_num] On [gamedata] ([num] );
CREATE INDEX [results_result] On [results] ([result]);
CREATE INDEX [results_role] On [results] ([role]);
CREATE INDEX [results_general] On [results] ([general]);
CREATE INDEX [results_kingdom] On [results] ([kingdom]);
CREATE INDEX [results_hegemony] On [results] ([hegemony]);
CREATE INDEX [results_mode] On [results] ([mode]);
CREATE INDEX [gongxun_score] On [gongxun] ([score]);
CREATE INDEX [gongxun_category] On [gongxun] ([category]);
CREATE INDEX [zhangong_category] On [zhangong] ([category]);
CREATE INDEX [zhangong_general] On [zhangong] ([general]);
CREATE INDEX [zhangong_num] On [zhangong] ([num]);
CREATE INDEX [skills_gained] On [skills] ([gained]);
CREATE INDEX [skills_used] On [skills] ([used]);
INSERT INTO "gongxun" VALUES(0, '平民', 0, 'wen');
INSERT INTO "gongxun" VALUES(1, '里长', 100, 'wen');
INSERT INTO "gongxun" VALUES(2, '亭长', 300, 'wen');
INSERT INTO "gongxun" VALUES(3, '蔷夫', 600, 'wen');
INSERT INTO "gongxun" VALUES(4, '县尉', 1000, 'wen');
INSERT INTO "gongxun" VALUES(5, '郎中', 1500, 'wen');
INSERT INTO "gongxun" VALUES(6, '侍郎', 2100, 'wen');
INSERT INTO "gongxun" VALUES(7, '县丞', 2800, 'wen');
INSERT INTO "gongxun" VALUES(8, '县长', 3600, 'wen');
INSERT INTO "gongxun" VALUES(9, '博士', 4500, 'wen');
INSERT INTO "gongxun" VALUES(10, '议郎', 5500, 'wen');
INSERT INTO "gongxun" VALUES(11, '中郎', 6600, 'wen');
INSERT INTO "gongxun" VALUES(12, '谒者', 7800, 'wen');
INSERT INTO "gongxun" VALUES(13, '郡长史', 9100, 'wen');
INSERT INTO "gongxun" VALUES(14, '州刺史', 10500, 'wen');
INSERT INTO "gongxun" VALUES(15, '郡太守丞', 12000, 'wen');
INSERT INTO "gongxun" VALUES(16, '谏大夫', 13600, 'wen');
INSERT INTO "gongxun" VALUES(17, '太常丞', 15300, 'wen');
INSERT INTO "gongxun" VALUES(18, '光禄丞', 17100, 'wen');
INSERT INTO "gongxun" VALUES(19, '卫尉丞', 19000, 'wen');
INSERT INTO "gongxun" VALUES(20, '太仆丞', 21000, 'wen');
INSERT INTO "gongxun" VALUES(21, '大鸿胪丞', 23100, 'wen');
INSERT INTO "gongxun" VALUES(22, '宗正丞', 25300, 'wen');
INSERT INTO "gongxun" VALUES(23, '大司农丞', 27600, 'wen');
INSERT INTO "gongxun" VALUES(24, '少府丞', 30000, 'wen');
INSERT INTO "gongxun" VALUES(25, '太中大夫', 32500, 'wen');
INSERT INTO "gongxun" VALUES(26, '谒者仆射', 35100, 'wen');
INSERT INTO "gongxun" VALUES(27, '廷尉正监', 37800, 'wen');
INSERT INTO "gongxun" VALUES(28, '中常侍', 40600, 'wen');
INSERT INTO "gongxun" VALUES(29, '尚书令', 43500, 'wen');
INSERT INTO "gongxun" VALUES(30, '御史中丞', 46500, 'wen');
INSERT INTO "gongxun" VALUES(31, '司徒长史', 49600, 'wen');
INSERT INTO "gongxun" VALUES(32, '太尉长史', 52800, 'wen');
INSERT INTO "gongxun" VALUES(33, '司空长史', 56100, 'wen');
INSERT INTO "gongxun" VALUES(34, '丞相司直', 59500, 'wen');
INSERT INTO "gongxun" VALUES(35, '光禄大夫', 63000, 'wen');
INSERT INTO "gongxun" VALUES(36, '侍中', 66600, 'wen');
INSERT INTO "gongxun" VALUES(37, '州牧', 70300, 'wen');
INSERT INTO "gongxun" VALUES(38, '郡太守', 74100, 'wen');
INSERT INTO "gongxun" VALUES(39, '执金吾', 78000, 'wen');
INSERT INTO "gongxun" VALUES(40, '太常', 82000, 'wen');
INSERT INTO "gongxun" VALUES(41, '光禄勋', 86100, 'wen');
INSERT INTO "gongxun" VALUES(42, '卫尉', 90300, 'wen');
INSERT INTO "gongxun" VALUES(43, '太仆', 94600, 'wen');
INSERT INTO "gongxun" VALUES(44, '廷尉', 99000, 'wen');
INSERT INTO "gongxun" VALUES(45, '大鸿胪', 103500, 'wen');
INSERT INTO "gongxun" VALUES(46, '宗正', 108100, 'wen');
INSERT INTO "gongxun" VALUES(47, '司徒', 112800, 'wen');
INSERT INTO "gongxun" VALUES(48, '太尉', 117600, 'wen');
INSERT INTO "gongxun" VALUES(49, '司空', 122500, 'wen');
INSERT INTO "gongxun" VALUES(50, '丞相', 127500, 'wen');
INSERT INTO "gongxun" VALUES(0, '平民', 0, 'wu');
INSERT INTO "gongxun" VALUES(1, '兵卒', 100, 'wu');
INSERT INTO "gongxun" VALUES(2, '屯长', 300, 'wu');
INSERT INTO "gongxun" VALUES(3, '军侯', 600, 'wu');
INSERT INTO "gongxun" VALUES(4, '军司马', 1000, 'wu');
INSERT INTO "gongxun" VALUES(5, '都尉', 1500, 'wu');
INSERT INTO "gongxun" VALUES(6, '校尉', 2100, 'wu');
INSERT INTO "gongxun" VALUES(7, '中郎将', 2800, 'wu');
INSERT INTO "gongxun" VALUES(8, '裨将军', 3600, 'wu');
INSERT INTO "gongxun" VALUES(9, '偏将军', 4500, 'wu');
INSERT INTO "gongxun" VALUES(10, '牙门将军', 5500, 'wu');
INSERT INTO "gongxun" VALUES(11, '伏波将军', 6600, 'wu');
INSERT INTO "gongxun" VALUES(12, '翊武将军', 7800, 'wu');
INSERT INTO "gongxun" VALUES(13, '翊师将军', 9100, 'wu');
INSERT INTO "gongxun" VALUES(14, '建威将军', 10500, 'wu');
INSERT INTO "gongxun" VALUES(15, '建武将军', 12000, 'wu');
INSERT INTO "gongxun" VALUES(16, '振威将军', 13600, 'wu');
INSERT INTO "gongxun" VALUES(17, '振武将军', 15300, 'wu');
INSERT INTO "gongxun" VALUES(18, '领军将军', 17100, 'wu');
INSERT INTO "gongxun" VALUES(19, '护军将军', 19000, 'wu');
INSERT INTO "gongxun" VALUES(20, '武卫将军', 21000, 'wu');
INSERT INTO "gongxun" VALUES(21, '中垒将军', 23100, 'wu');
INSERT INTO "gongxun" VALUES(22, '镇军将军', 25300, 'wu');
INSERT INTO "gongxun" VALUES(23, '抚军将军', 27600, 'wu');
INSERT INTO "gongxun" VALUES(24, '镇国将军', 30000, 'wu');
INSERT INTO "gongxun" VALUES(25, '龙骧将军', 32500, 'wu');
INSERT INTO "gongxun" VALUES(26, '平东将军', 35100, 'wu');
INSERT INTO "gongxun" VALUES(27, '平南将军', 37800, 'wu');
INSERT INTO "gongxun" VALUES(28, '平西将军', 40600, 'wu');
INSERT INTO "gongxun" VALUES(29, '平北将军', 43500, 'wu');
INSERT INTO "gongxun" VALUES(30, '安东将军', 46500, 'wu');
INSERT INTO "gongxun" VALUES(31, '安南将军', 49600, 'wu');
INSERT INTO "gongxun" VALUES(32, '安西将军', 52800, 'wu');
INSERT INTO "gongxun" VALUES(33, '安北将军', 56100, 'wu');
INSERT INTO "gongxun" VALUES(34, '镇东将军', 59500, 'wu');
INSERT INTO "gongxun" VALUES(35, '镇南将军', 63000, 'wu');
INSERT INTO "gongxun" VALUES(36, '镇西将军', 66600, 'wu');
INSERT INTO "gongxun" VALUES(37, '镇北将军', 70300, 'wu');
INSERT INTO "gongxun" VALUES(38, '征东将军', 74100, 'wu');
INSERT INTO "gongxun" VALUES(39, '征南将军', 78000, 'wu');
INSERT INTO "gongxun" VALUES(40, '征西将军', 82000, 'wu');
INSERT INTO "gongxun" VALUES(41, '征北将军', 86100, 'wu');
INSERT INTO "gongxun" VALUES(42, '前将军', 90300, 'wu');
INSERT INTO "gongxun" VALUES(43, '后将军', 94600, 'wu');
INSERT INTO "gongxun" VALUES(44, '左将军', 99000, 'wu');
INSERT INTO "gongxun" VALUES(45, '右将军', 103500, 'wu');
INSERT INTO "gongxun" VALUES(46, '骠骑将军', 108100, 'wu');
INSERT INTO "gongxun" VALUES(47, '车骑将军', 112800, 'wu');
INSERT INTO "gongxun" VALUES(48, '卫将军', 117600, 'wu');
INSERT INTO "gongxun" VALUES(49, '安国将军', 122500, 'wu');
INSERT INTO "gongxun" VALUES(50, '大将军', 127500, 'wu');
INSERT INTO "skills" VALUES('zhiyu', 0, 0);
INSERT INTO "skills" VALUES('miji', 0, 0);
INSERT INTO "skills" VALUES('anxu', 0, 0);
INSERT INTO "skills" VALUES('jiangchi', 0, 0);
INSERT INTO "skills" VALUES('zishou', 0, 0);
INSERT INTO "skills" VALUES('zongshi', 0, 0);
INSERT INTO "skills" VALUES('lihuo', 0, 0);
INSERT INTO "skills" VALUES('mashu', 0, 0);
INSERT INTO "skills" VALUES('kuanggu', 0, 0);
INSERT INTO "skills" VALUES('liegong', 0, 0);
INSERT INTO "skills" VALUES('shensu', 0, 0);
INSERT INTO "skills" VALUES('hongyuan', 0, 0);
INSERT INTO "skills" VALUES('mingzhe', 0, 0);
INSERT INTO "skills" VALUES('wansha', 0, 0);
INSERT INTO "skills" VALUES('yinghun', 0, 0);
INSERT INTO "skills" VALUES('weimu', 0, 0);
INSERT INTO "skills" VALUES('roulin', 0, 0);
INSERT INTO "skills" VALUES('zaiqi', 0, 0);
INSERT INTO "skills" VALUES('haoshi', 0, 0);
INSERT INTO "skills" VALUES('dimeng', 0, 0);
INSERT INTO "skills" VALUES('xingshang', 0, 0);
INSERT INTO "skills" VALUES('fangzhu', 0, 0);
INSERT INTO "skills" VALUES('duanliang', 0, 0);
INSERT INTO "skills" VALUES('lieren', 0, 0);
INSERT INTO "skills" VALUES('longdan', 0, 0);
INSERT INTO "skills" VALUES('qicai', 0, 0);
INSERT INTO "skills" VALUES('tieji', 0, 0);
INSERT INTO "skills" VALUES('wushuang', 0, 0);
INSERT INTO "skills" VALUES('tiandu', 0, 0);
INSERT INTO "skills" VALUES('guose', 0, 0);
INSERT INTO "skills" VALUES('zhiheng', 0, 0);
INSERT INTO "skills" VALUES('lijian', 0, 0);
INSERT INTO "skills" VALUES('biyue', 0, 0);
INSERT INTO "skills" VALUES('ganglie', 0, 0);
INSERT INTO "skills" VALUES('qianxun', 0, 0);
INSERT INTO "skills" VALUES('wusheng', 0, 0);
INSERT INTO "skills" VALUES('qingguo', 0, 0);
INSERT INTO "skills" VALUES('fankui', 0, 0);
INSERT INTO "skills" VALUES('jianxiong', 0, 0);
INSERT INTO "skills" VALUES('guanxing', 0, 0);
INSERT INTO "skills" VALUES('tuxi', 0, 0);
INSERT INTO "skills" VALUES('yingzi', 0, 0);
INSERT INTO "skills" VALUES('fanjian', 0, 0);
INSERT INTO "skills" VALUES('dahe', 0, 0);
INSERT INTO "skills" VALUES('yanzheng', 0, 0);
INSERT INTO "skills" VALUES('tanhu', 0, 0);
INSERT INTO "skills" VALUES('yanxiao', 0, 0);
INSERT INTO "skills" VALUES('anxian', 0, 0);
INSERT INTO "skills" VALUES('jilei', 0, 0);
INSERT INTO "skills" VALUES('danlao', 0, 0);
INSERT INTO "skills" VALUES('weidi', 0, 0);
INSERT INTO "skills" VALUES('yicong', 0, 0);
INSERT INTO "skills" VALUES('mengjin', 0, 0);
INSERT INTO "skills" VALUES('xiuluo', 0, 0);
INSERT INTO "skills" VALUES('shenwei', 0, 0);
INSERT INTO "skills" VALUES('shenji', 0, 0);
INSERT INTO "skills" VALUES('zhulou', 0, 0);
INSERT INTO "skills" VALUES('tannang', 0, 0);
INSERT INTO "skills" VALUES('neofanjian', 0, 0);
INSERT INTO "skills" VALUES('yishi', 0, 0);
INSERT INTO "skills" VALUES('enyuan', 0, 0);
INSERT INTO "skills" VALUES('xuanhuo', 0, 0);
INSERT INTO "skills" VALUES('xianzhen', 0, 0);
INSERT INTO "skills" VALUES('xuanfeng', 0, 0);
INSERT INTO "skills" VALUES('yizhong', 0, 0);
INSERT INTO "skills" VALUES('shangshi', 0, 0);
INSERT INTO "skills" VALUES('ganlu', 0, 0);
INSERT INTO "skills" VALUES('luoying', 0, 0);
INSERT INTO "skills" VALUES('jujian', 0, 0);
INSERT INTO "skills" VALUES('xinzhan', 0, 0);
INSERT INTO "skills" VALUES('zhichi', 0, 0);
INSERT INTO "skills" VALUES('mingce', 0, 0);
INSERT INTO "skills" VALUES('pojun', 0, 0);
INSERT INTO "skills" VALUES('qiangxi', 0, 0);
INSERT INTO "skills" VALUES('lianhuan', 0, 0);
INSERT INTO "skills" VALUES('tianyi', 0, 0);
INSERT INTO "skills" VALUES('bazhen', 0, 0);
INSERT INTO "skills" VALUES('quhu', 0, 0);
INSERT INTO "skills" VALUES('luanji', 0, 0);
INSERT INTO "skills" VALUES('feiying', 0, 0);
INSERT INTO "skills" VALUES('qinyin', 0, 0);
INSERT INTO "skills" VALUES('juejing', 0, 0);
INSERT INTO "skills" VALUES('shelie', 0, 0);
INSERT INTO "skills" VALUES('gongxin', 0, 0);
INSERT INTO "skills" VALUES('jiang', 0, 0);
INSERT INTO "skills" VALUES('guzheng', 0, 0);
INSERT INTO "skills" VALUES('zhijian', 0, 0);
INSERT INTO "skills" VALUES('tiaoxin', 0, 0);
INSERT INTO "skills" VALUES('xiangle', 0, 0);
INSERT INTO "skills" VALUES('fangquan', 0, 0);
INSERT INTO "skills" VALUES('nosenyuan', 0, 0);
INSERT INTO "skills" VALUES('jueqing', 0, 0);
INSERT INTO "skills" VALUES('yiji', 0, 0);
INSERT INTO "skills" VALUES('liuli', 0, 0);
INSERT INTO "skills" VALUES('neoganglie', 0, 0);
INSERT INTO "skills" VALUES('beige', 0, 0);
INSERT INTO "skills" VALUES('zhiji', 0, 0);
INSERT INTO "skills" VALUES('zhiba', 0, 0);
INSERT INTO "skills" VALUES('nosxuanhuo', 0, 0);
INSERT INTO "skills" VALUES('juxiang', 0, 0);
INSERT INTO "gamedata" VALUES('bszj', 0);
INSERT INTO "gamedata" VALUES('yqt', 0);
INSERT INTO "gamedata" VALUES('gddph', 0);
INSERT INTO "gamedata" VALUES('ph', 0);
INSERT INTO zhangong VALUES('ajnf', '暗箭难防', 10, '使用马岱在一局游戏中发动“潜袭”成功至少6次', 0, 'shu', '1999-12-31 00:00:00', 'madai', 0, 0);
INSERT INTO zhangong VALUES('bj', '暴君', 15, '身为主公在1局游戏中，在反贼和内奸全部存活的情况下杀死全部忠臣，并最后胜利', 0, 'zhonghe', '1999-12-31 00:00:00', '-', 0, 0);
INSERT INTO zhangong VALUES('bjz', '败家子', 15, '在一局游戏中，弃牌阶段累计弃掉至少10张桃', 0, 'zhonghe', '1999-12-31 00:00:00', '-', 0, 0);
INSERT INTO zhangong VALUES('bnzw', '暴虐之王', 10, '使用董卓在一局游戏中利用技能“暴虐”至少回血10次', 0, 'qun', '1999-12-31 00:00:00', 'dongzhuo', 0, 0);
INSERT INTO zhangong VALUES('bqbr', '不屈不饶', 15, '一格体力情况下，累积出闪100次', 0, 'zhonghe', '1999-12-31 00:00:00', '-', 0, 0);
INSERT INTO zhangong VALUES('bqk', '兵器库', 15, '在一局游戏中，累计装备过至少10次武器以及10次防具', 0, 'zhonghe', '1999-12-31 00:00:00', '-', 0, 0);
INSERT INTO zhangong VALUES('brz', '百人斩', 15, '累积杀死100人', 0, 'zhonghe', '1999-12-31 00:00:00', '-', 0, 0);
INSERT INTO zhangong VALUES('cbhw', '长坂虎威', 10, '使用张飞在一回合内使用8张杀', 0, 'shu', '1999-12-31 00:00:00', 'zhangfei', 0, 0);
INSERT INTO zhangong VALUES('cbyx', '长坂英雄', 10, '使用赵云在一局游戏中，在刘禅为队友且存活情况下获胜', 0, 'shu', '1999-12-31 00:00:00', 'zhaoyun', 0, 0);
INSERT INTO zhangong VALUES('cqb', '拆迁办', 15, '在一个回合内使用卡牌过河拆桥/顺手牵羊累计4次', 0, 'zhonghe', '1999-12-31 00:00:00', '-', 0, 0);
INSERT INTO zhangong VALUES('cqcz', '此情常在', 10, '在一局游戏中，布练师发动安恤4次并在阵亡情况下获胜', 0, 'wu', '1999-12-31 00:00:00', 'bulianshi', 0, 0);
INSERT INTO zhangong VALUES('cqdd', '拆迁大队', 15, '在一局游戏中，累计使用卡牌过河拆桥10次以上', 0, 'zhonghe', '1999-12-31 00:00:00', '-', 0, 0);
INSERT INTO zhangong VALUES('ctbc', '拆桃不偿', 10, '使用甘宁在一局游戏中至少拆掉对方5张桃', 0, 'wu', '1999-12-31 00:00:00', 'ganning', 0, 0);
INSERT INTO zhangong VALUES('dcxj', '雕虫小技', 10, '使用卧龙在一局游戏中发动“看破”至少15次', 0, 'shu', '1999-12-31 00:00:00', 'wolong', 0, 0);
INSERT INTO zhangong VALUES('dkjj', '荡寇将军', 10, '使用程普在一局游戏中，发动技能“疠火”杀死至少三名反贼最终获得胜利', 0, 'wu', '1999-12-31 00:00:00', 'chengpu', 0, 0);
INSERT INTO zhangong VALUES('dkzz', '杜康之子', 10, '使用曹植在一局游戏中发动酒诗后成功用杀造成伤害累计5次', 0, 'wei', '1999-12-31 00:00:00', 'caozhi', 0, 0);
INSERT INTO zhangong VALUES('dqzw', '大权在握', 10, '使用钟会在一局游戏中有超过8张权', 0, 'wei', '1999-12-31 00:00:00', 'zhonghui', 0, 0);
INSERT INTO zhangong VALUES('dgxl', '东宫西略', 15, '在一局游戏中，身份为男性主公，而忠臣为两名女性武将并在女性忠臣全部存活的情况下获胜', 0, 'zhonghe', '1999-12-31 00:00:00', '-', 0, 0);
INSERT INTO zhangong VALUES('dym', '大姨妈', 10, '使用甄姬连续5回合洛神的第一次结果都是红色，不包括改判', 0, 'wei', '1999-12-31 00:00:00', 'zhenji', 0, 0);
INSERT INTO zhangong VALUES('dyzh', '当阳之吼', 10, '在一局游戏中，使用☆SP张飞累计发动大喝与一名角色拼点成功的回合中用红“杀”手刃该角色', 0, 'shu', '1999-12-31 00:00:00', 'bgm_zhangfei', 0, 0);
INSERT INTO zhangong VALUES('fynd', '愤勇难当', 10, '使用☆SP夏侯惇在一局游戏中，至少发动四次愤勇', 0, 'wei', '1999-12-31 00:00:00', 'bgm_xiahoudun', 0, 0);
INSERT INTO zhangong VALUES('gjcc', '诡计重重', 15, '在一局游戏中，累计使用锦囊牌至少20次', 0, 'zhonghe', '1999-12-31 00:00:00', '-', 0, 0);
INSERT INTO zhangong VALUES('glnc', '刚烈难存', 10, '使用夏侯惇在一局游戏中连续4次刚烈判定均为红桃', 0, 'wei', '1999-12-31 00:00:00', 'xiahoudun', 0, 0);
INSERT INTO zhangong VALUES('gmzc', '过目之才', 10, '使用☆SP庞统一回合内累计拿到至少16张牌', 0, 'shu', '1999-12-31 00:00:00', 'bgm_pangtong', 0, 0);
INSERT INTO zhangong VALUES('gn', '果农', 15, '游戏开始时，起手4张“桃”', 0, 'zhonghe', '1999-12-31 00:00:00', '-', 0, 0);
INSERT INTO zhangong VALUES('gqzl', '顾曲周郎', 10, '使用神周瑜连续至少4回合发动琴音回复体力', 0, 'god', '1999-12-31 00:00:00', 'shenzhouyu', 0, 0);
INSERT INTO zhangong VALUES('gzwb', '固政为本', 10, '使用张昭张纮在一局游戏中利用技能“固政”获得累计至少40张牌', 0, 'wu', '1999-12-31 00:00:00', 'erzhang', 0, 0);
INSERT INTO zhangong VALUES('hjqy', '黄巾起义', 10, '使用张角在一局游戏中收到过群雄角色给的闪至少3张，并至少3次雷击成功', 0, 'qun', '1999-12-31 00:00:00', 'zhangjiao', 0, 0);
INSERT INTO zhangong VALUES('hlzms', '挥泪斩马谡', 10, '使用诸葛亮杀死马谡', 0, 'shu', '1999-12-31 00:00:00', 'zhugeliang', 0, 0);
INSERT INTO zhangong VALUES('htdl', '黄天当立', 15, '使用张角在一局游戏中通过黄天得到的闪不少于8张', 0, 'qun', '1999-12-31 00:00:00', 'zhangjiao', 0, 0);
INSERT INTO zhangong VALUES('hztx', '虎子同心', 10, '使用关兴张苞在父魂成功后，一个回合杀死至少三名反贼', 0, 'shu', '1999-12-31 00:00:00', 'guanxingzhangbao', 0, 0);
INSERT INTO zhangong VALUES('jcyd', '将驰有度', 10, '使用曹彰发动将驰的两种效果各连续两回合', 0, 'wei', '1999-12-31 00:00:00', 'caozhang', 0, 0);
INSERT INTO zhangong VALUES('jdfy', '绝对防御', 15, '在一局游戏中，使用八挂累计出闪20次', 0, 'zhonghe', '1999-12-31 00:00:00', '-', 0, 0);
INSERT INTO zhangong VALUES('jfhz', '解烦护主', 10, '使用韩当在一局游戏游戏中发动“解烦”救过队友孙权至少两次', 0, 'wu', '1999-12-31 00:00:00', 'handang', 0, 0);
INSERT INTO zhangong VALUES('jg', '酒鬼', 15, '出牌阶段开始时，手牌中至少有3张“酒”', 0, 'zhonghe', '1999-12-31 00:00:00', '-', 0, 0);
INSERT INTO zhangong VALUES('jhlt', '举火燎天', 15, '在一局游戏中，造成火焰伤害累计10点以上，不含武将技能', 0, 'zhonghe', '1999-12-31 00:00:00', '-', 0, 0);
INSERT INTO zhangong VALUES('jjfs', '绝境逢生', 10, '使用神赵云在一局游戏中,当体力为一的时候，一直保持一体力直到游戏获胜', 0, 'god', '1999-12-31 00:00:00', 'shenzhaoyun', 0, 0);
INSERT INTO zhangong VALUES('jjh', '交际花', 10, '使用孙尚香和全部其他(且至少4个)角色皆使用过结姻', 0, 'wu', '1999-12-31 00:00:00', 'sunshangxiang', 0, 0);
INSERT INTO zhangong VALUES('jjnh', '禁军难护', 10, '使用韩当在一局游戏中有角色濒死时发动“解烦”并出杀后均被闪避至少5次', 0, 'wu', '1999-12-31 00:00:00', 'handang', 0, 0);
INSERT INTO zhangong VALUES('jjyb', '戒酒以备', 10, '使用高顺在一局游戏中使用技能“禁酒”将至少6张酒当成杀使用或打出', 0, 'qun', '1999-12-31 00:00:00', 'gaoshun', 0, 0);
INSERT INTO zhangong VALUES('jsbc', '坚守不出', 10, '使用曹仁在一局游戏中连续8回合发动据守', 0, 'wei', '1999-12-31 00:00:00', 'caoren', 0, 0);
INSERT INTO zhangong VALUES('jwrs', '军威如山', 10, '使用☆SP甘宁在一局游戏中发动军威累计得到过至少6张“闪”', 0, 'wu', '1999-12-31 00:00:00', 'bgm_ganning', 0, 0);
INSERT INTO zhangong VALUES('jyh', '解语花', 10, '使用步练师在一局游戏中发动安恤摸八张牌以上', 0, 'wu', '1999-12-31 00:00:00', 'bulianshi', 0, 0);
INSERT INTO zhangong VALUES('lpkd', '连破克敌', 10, '使用神司马懿在一局游戏中发动3次连破并最后获胜', 0, 'god', '1999-12-31 00:00:00', 'shensimayi', 0, 0);
INSERT INTO zhangong VALUES('qbcs', '七步成诗', 10, '使用曹植在一局游戏中发动酒诗7次', 0, 'wei', '1999-12-31 00:00:00', 'caozhi', 0, 0);
INSERT INTO zhangong VALUES('qjbc', '奇计百出', 10, '使用荀攸在一局游戏中，发动“奇策”使用至少六种锦囊', 0, 'wei', '1999-12-31 00:00:00', 'xunyou', 0, 0);
INSERT INTO zhangong VALUES('qldy', '枪林弹雨', 10, '使用袁绍在一回合内发动8次乱击', 0, 'qun', '1999-12-31 00:00:00', 'yuanshao', 0, 0);
INSERT INTO zhangong VALUES('qmjj', '奇谋九计', 10, '使用王异在一局游戏中至少成功发动九次秘计并获胜。', 0, 'wei', '1999-12-31 00:00:00', 'wangyi', 0, 0);
INSERT INTO zhangong VALUES('qqtx', '权倾天下', 10, '使用钟会在一局游戏中发动“排异”累计摸牌至少10张', 0, 'wei', '1999-12-31 00:00:00', 'zhonghui', 0, 0);
INSERT INTO zhangong VALUES('qrz', '千人斩', 15, '累积杀1000人', 0, 'zhonghe', '1999-12-31 00:00:00', '-', 0, 0);
INSERT INTO zhangong VALUES('qshs', '起死回生', 15, '在一局游戏中，累计受过至少20点伤害且最后存活获胜', 0, 'zhonghe', '1999-12-31 00:00:00', '-', 0, 0);
INSERT INTO zhangong VALUES('rxbz', '仁心布众', 10, '使用刘备在一局游戏中，累计仁德至少30张牌', 0, 'shu', '1999-12-31 00:00:00', 'liubei', 0, 0);
INSERT INTO zhangong VALUES('sbfs', '生不逢时', 10, '使用双雄对关羽使用决斗，并因这个决斗被关羽杀死', 0, 'qun', '1999-12-31 00:00:00', 'yanliangwenchou', 0, 0);
INSERT INTO zhangong VALUES('sfgj', '三分归晋', 10, '使用神司马懿杀死刘备，孙权，曹操各累计10次', 0, 'god', '1999-12-31 00:00:00', 'shensimayi', 0, 0);
INSERT INTO zhangong VALUES('shgx', '四海归心', 10, '使用神曹操在一局游戏中受到2点伤害之后发动2次归心', 0, 'god', '1999-12-31 00:00:00', 'shencaocao', 0, 0);
INSERT INTO zhangong VALUES('ssex', '三思而行', 10, '使用孙权在一局游戏中利用制衡获得至少4张无中生有以及4张桃', 0, 'wu', '1999-12-31 00:00:00', 'sunquan', 0, 0);
INSERT INTO zhangong VALUES('sssl', '深思熟虑', 10, '使用孙权在一个回合内发动制衡的牌不少于10张', 0, 'wu', '1999-12-31 00:00:00', 'sunquan', 0, 0);
INSERT INTO zhangong VALUES('stzs', '神偷再世', 15, '在一局游戏中，累计使用卡牌顺手牵羊10次以上', 0, 'zhonghe', '1999-12-31 00:00:00', '-', 0, 0);
INSERT INTO zhangong VALUES('swzs', '神威之势', 10, '使用神赵云发动各花色龙魂各两次并在存活的情况下取得游戏胜利', 0, 'god', '1999-12-31 00:00:00', 'shenzhaoyun', 0, 0);
INSERT INTO zhangong VALUES('syjh', '岁月静好', 10, '使用☆SP大乔在一局游戏中发动安娴五次并获胜', 0, 'wu', '1999-12-31 00:00:00', 'bgm_daqiao', 0, 0);
INSERT INTO zhangong VALUES('syqd', '恃勇轻敌', 10, '使用华雄在一局游戏中，在没有马岱在场的情况下由于体力上限减至0而死亡', 0, 'qun', '1999-12-31 00:00:00', 'huaxiong', 0, 0);
INSERT INTO zhangong VALUES('thy', '桃花运', 15, '当你的开局4牌全部为红桃时，体力上限加1', 0, 'zhonghe', '1999-12-31 00:00:00', '-', 0, 0);
INSERT INTO zhangong VALUES('tmnw', '天命难违', 10, '使用司马懿被自己挂的闪电劈死，不包括改判', 0, 'wei', '1999-12-31 00:00:00', 'simayi', 0, 0);
INSERT INTO zhangong VALUES('tmzf', '天命之罚', 10, '在一局游戏中，使用司马懿更改闪电判定牌至少劈中其他角色两次', 0, 'wei', '1999-12-31 00:00:00', 'simayi', 0, 0);
INSERT INTO zhangong VALUES('tyzm', '桃园之梦', 10, '使用神关羽在一局游戏中阵亡后发动武魂判定结果为桃园结义', 0, 'god', '1999-12-31 00:00:00', 'shenguanyu', 0, 0);
INSERT INTO zhangong VALUES('tyzy', '桃园之义', 15, '在一局游戏中，场上同时存在刘备、关羽、张飞三人且为队友，而你是其中一个并最后获胜', 0, 'zhonghe', '1999-12-31 00:00:00', '-', 0, 0);
INSERT INTO zhangong VALUES('wmsz', '无谋竖子', 10, '使用神吕布在一局游戏中发动无谋至少8次', 0, 'god', '1999-12-31 00:00:00', 'shenlvbu', 0, 0);
INSERT INTO zhangong VALUES('wsww', '为时未晚', 15, '身为反贼，在一局游戏中杀死了除自己以外所有反贼并获得游戏的胜利', 0, 'zhonghe', '1999-12-31 00:00:00', '-', 0, 0);
INSERT INTO zhangong VALUES('wxwd', '惟贤惟德', 10, '使用刘备在一个回合内发动仁德给的牌不少于10张', 0, 'shu', '1999-12-31 00:00:00', 'liubei', 0, 0);
INSERT INTO zhangong VALUES('wyyd', '无言以对', 10, '使用徐庶在一局游戏中发动“无言”躲过南蛮入侵或万箭齐发累计4次', 0, 'shu', '1999-12-31 00:00:00', 'xushu', 0, 0);
INSERT INTO zhangong VALUES('wzxj', '稳重行军', 10, '使用于禁在一局游戏中发动“毅重”抵御至少4次黑色杀', 0, 'wei', '1999-12-31 00:00:00', 'yujin', 0, 0);
INSERT INTO zhangong VALUES('xcdz', '星驰电走', 15, '在一局游戏中，累计出闪20次', 0, 'zhonghe', '1999-12-31 00:00:00', '-', 0, 0);
INSERT INTO zhangong VALUES('xhdc', '雪恨敌耻', 10, '使用☆SP夏侯惇在一局游戏中，发动雪恨杀死一名角色', 0, 'wei', '1999-12-31 00:00:00', 'bgm_xiahoudun', 0, 0);
INSERT INTO zhangong VALUES('xhjs', '悬壶济世', 15, '在一局游戏中，使用桃或技能累计将我方队友脱离濒死状态4次以上', 0, 'zhonghe', '1999-12-31 00:00:00', '-', 0, 0);
INSERT INTO zhangong VALUES('xlfm', '小露锋芒', 15, '进行1000局游戏', 0, 'zhonghe', '1999-12-31 00:00:00', '-', 0, 0);
INSERT INTO zhangong VALUES('xlwzy', '星落五丈原', 10, '使用诸葛亮，在司马懿为敌方时阵亡', 0, 'shu', '1999-12-31 00:00:00', 'zhugeliang', 0, 0);
INSERT INTO zhangong VALUES('xnhx', '邪念惑心', 15, '作为忠臣在一局游戏中，在场上没有反贼时手刃主公', 0, 'zhonghe', '1999-12-31 00:00:00', '-', 0, 0);
INSERT INTO zhangong VALUES('xxf', '小旋风', 10, '使用凌统在一局游戏中发动技能“旋风”弃掉其他角色累计15张牌', 0, 'wu', '1999-12-31 00:00:00', 'lingtong', 0, 0);
INSERT INTO zhangong VALUES('xysc', '小有所成', 15, '进行100局游戏', 0, 'zhonghe', '1999-12-31 00:00:00', '-', 0, 0);
INSERT INTO zhangong VALUES('xzxm', '先知续命', 10, '使用郭嘉在一局游戏中利用技能“天妒”收进至少4个桃', 0, 'wei', '1999-12-31 00:00:00', 'guojia', 0, 0);
INSERT INTO zhangong VALUES('ybyt', '义薄云天', 10, '使用SP关羽在觉醒后杀死两个反贼并最后获胜', 0, 'wei', '1999-12-31 00:00:00', 'sp_guanyu', 0, 0);
INSERT INTO zhangong VALUES('ymds', '驭马大师', 15, '在一局游戏中，至少更换过8匹马', 0, 'zhonghe', '1999-12-31 00:00:00', '-', 0, 0);
INSERT INTO zhangong VALUES('ynnd', '有难你当', 10, '使用小乔在一局游戏中发动“天香”导致一名其他角色死亡', 0, 'wu', '1999-12-31 00:00:00', 'xiaoqiao', 0, 0);
INSERT INTO zhangong VALUES('yrbf', '隐忍不发', 10, '使用神司马懿在一局游戏中发动忍戒至少10次并获胜', 0, 'god', '1999-12-31 00:00:00', 'shensimayi', 0, 0);
INSERT INTO zhangong VALUES('ysadj', '以死安大局', 10, '使用马谡在一局游戏中发动“挥泪”使一名角色弃置8张牌', 0, 'shu', '1999-12-31 00:00:00', 'masu', 0, 0);
INSERT INTO zhangong VALUES('yzrx', '医者仁心', 10, '使用华佗在一局游戏中对4个身份的人都发动过青囊并最后获胜', 0, 'qun', '1999-12-31 00:00:00', 'huatuo', 0, 0);
INSERT INTO zhangong VALUES('zlzn', '昭烈之怒', 10, '在一局游戏中，使用☆SP刘备发动昭烈杀死至少2人', 0, 'shu', '1999-12-31 00:00:00', 'bgm_liubei', 0, 0);
INSERT INTO zhangong VALUES('zmjzg', '走马荐诸葛', 10, '使用旧徐庶在一局游戏中至少有3次举荐诸葛且用于举荐的牌里必须有马', 0, 'shu', '1999-12-31 00:00:00', 'xushu', 0, 0);
INSERT INTO zhangong VALUES('zsbsh', '宗室遍四海', 10, '使用刘表在一局游戏中利用技能“宗室”提高4手牌上限', 0, 'qun', '1999-12-31 00:00:00', 'liubiao', 0, 0);
INSERT INTO zhangong VALUES('zszn', '战神之怒', 10, '使用神吕布在一局游戏中发动至少4次神愤、3次无前', 0, 'god', '1999-12-31 00:00:00', 'shenlvbu', 0, 0);
INSERT INTO zhangong VALUES('zzhs', '智之化身', 10, '使用黄月英在一局游戏发动“集智”至少20次', 0, 'shu', '1999-12-31 00:00:00', 'huangyueying', 0, 0);
INSERT INTO zhangong VALUES('sxnj', '神仙难救', 10, '使用贾诩在你的回合中有至少3个角色阵亡', 0, 'qun', '1999-12-31 00:00:00', 'jiaxu', 0, 0);
INSERT INTO zhangong VALUES('jzyf', '见者有份', 10, '使用杨修在一局游戏中发动技能“啖酪”至少6次', 0, 'wei', '1999-12-31 00:00:00', 'yangxiu', 0, 0);
INSERT INTO zhangong VALUES('xhrb', '心如寒冰', 10, '使用张春华在一局游戏中至少触发“绝情”10次以上', 0, 'wei', '1999-12-31 00:00:00', 'zhangchunhua', 0, 0);
INSERT INTO zhangong VALUES('lbss', '乐不思蜀', 10, '在对你的“乐不思蜀”生效后的回合弃牌阶段弃置超过8张手牌', 0, 'zhonghe', '1999-12-31 00:00:00', '-', 0, 0);
INSERT INTO zhangong VALUES('ydqb', '原地起爆', 10, '回合开始阶段你1血0牌的情况下，一回合内杀死3名角色', 0, 'zhonghe', '1999-12-31 00:00:00', '-', 0, 0);
INSERT INTO zhangong VALUES('hyhs', '红颜祸水', 10, '使用SP貂蝉在一局游戏中，两次对主公和忠臣发动技能“离间”并导致2名忠臣阵亡', 0, 'qun', '1999-12-31 00:00:00', 'sp_diaochan', 0, 0);
INSERT INTO zhangong VALUES('wzsh', '威震四海', 15, '一次对另外一名角色造成至少5点伤害', 0, 'zhonghe', '1999-12-31 00:00:00', '-', 0, 0);
INSERT INTO zhangong VALUES('dsdnx', '屌丝的逆袭', 15, '身为虎牢关联军的先锋，第一回合就爆了虎牢布的菊花', 0, 'zhonghe', '1999-12-31 00:00:00', '-', 0, 0);
INSERT INTO zhangong VALUES('kdzz', '坑爹自重', 15, '使用刘禅，孙权&孙策，曹丕&曹植坑了自己的老爹', 0, 'zhonghe', '1999-12-31 00:00:00', '-', 0, 0);
COMMIT;