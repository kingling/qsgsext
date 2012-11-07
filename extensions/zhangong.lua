dofile "lua/config.lua"
dofile "lua/sgs_ex.lua"

module("extensions.zhangong", package.seeall)
extension = sgs.Package("zhangong")
zganjiang=sgs.General(extension, "zganjiang", "qun", 5, true,true,true)

zgfunc={}
zgturndata={}
zggamedata={}

zggamedata.turncount=0
zggamedata.roomid=0
zggamedata.enable=0
zggamedata.hegemony=0

zgfunc[sgs.CardEffect]={}
zgfunc[sgs.CardEffected]={}
zgfunc[sgs.CardFinished]={}
zgfunc[sgs.CardsMoveOneTime]={}
zgfunc[sgs.CardDiscarded]={}
zgfunc[sgs.CardResponsed]={}
zgfunc[sgs.ChoiceMade]={}


zgfunc[sgs.ConfirmDamage]={}
zgfunc[sgs.Damage]={}
zgfunc[sgs.DamageCaused]={}
zgfunc[sgs.Damaged]={}
zgfunc[sgs.DamageComplete]={}
zgfunc[sgs.DamageInflicted]={}


zgfunc[sgs.Death]={}
zgfunc[sgs.EventPhaseEnd]={}
zgfunc[sgs.EventPhaseStart]={}

zgfunc[sgs.FinishRetrial]={}

zgfunc[sgs.GameStart]={}
zgfunc[sgs.GameOverJudge]={}
zgfunc[sgs.GameOverJudge]["callback"]={}
zgfunc[sgs.HpRecover]={}

zgfunc[sgs.SlashEffect]={}
zgfunc[sgs.SlashEffected]={}

zgfunc[sgs.TurnStart]={}
zgfunc[sgs.Pindian]={}

sgs.Todo=9999
zgfunc[sgs.Todo]={}

require "sqlite3"
db = sqlite3.open("./zhangong/zhangong_dev.data")
local tblquery=db:first_row("select count(name) as tblnum from sqlite_master  where type='table';")
if tblquery.tblnum==0 then
	local sqltbl = (io.open "./zhangong/zhangong_dev.sql"):read("*a"):split("\n")
	for _,line in ipairs(sqltbl) do
		db:exec(line)
	end
end

local tblquery=db:first_row("select count(name) as tblnum from sqlite_master  where type='table' and name='card';")
if tblquery.tblnum==0 then
	db:exec("CREATE TABLE zgcard([id] varchar(20) NOT NULL,[gained] int(11) NOT NULL,[used] int(11) NOT NULL, Primary Key(id) ON CONFLICT Ignore);")
	db:exec("insert into zgcard values('luckycard',100,0);")
end

function logmsg(fmt,...)
	local fp = io.open("zgdebug.log","ab")
	if type(fmt)=="boolean" then fmt = fmt and "true" or "false" end
	fp:write(string.format(fmt, unpack(arg)).."\r\n")
	fp:close()
end

function sqlexec(sql,...)
	local sqlstr=string.format(sql, unpack(arg))
	db:exec(sqlstr)
end


function database2js()
	return false
end


-- 游戏结束判断代码， 
-- 因为游戏结束的时候，当前阵亡的人的 sgs.Death 事件不会被触发，sgs.cardFinished也不会被触发，这里额外处理
-- zgfunc[sgs.GameOverJudge]["callback"] 处理最后一个阵亡的人的 Death事件
zgfunc[sgs.GameOverJudge].tongji=function(self, room, event, player, data,isowner,name)
	local winner=getWinner(room,player)	
	if not winner then return false end
	local winlist= winner:split("+")
	local owner=room:getOwner()
	local result = (table.contains(winlist, owner:getRole()) or table.contains(winlist, owner:objectName())) and 'win' or 'lose'
	local alive=owner:isAlive() and 1 or 0	
	local damage =data:toDamageStar()
	
	if damage and damage.from and damage.from:objectName()==room:getOwner():objectName() then
		addTurnData("expval", math.min(damage.damage,8))
		if damage.card then
			if damage.card:isKindOf("TrickCard") then addTurnData("wen",1) end
			if damage.card:isKindOf("Slash")	 then addTurnData("wu",1) end
		end	
		--gainSkill(room)
	end
	
	local kingdom=room:getOwner():getKingdom()
	if kingdom=="god" and getGameData("hegemony")==1 then kingdom=room:getOwner():getGeneral():getKingdom() end

	sqlexec("update results set kingdom='%s', general='%s',turncount=%d,alive=%d,result='%s',wen=wen+%d,wu=wu+%d,expval=expval+%d where id=%d",
			kingdom,owner:getGeneralName(),getGameData("turncount"),alive,result,getTurnData("wen"),
			getTurnData("wu"),getTurnData("expval"),getGameData("roomid"))
	
	local callbacks=zgfunc[sgs.GameOverJudge]["callback"]
	for name, func in pairs(callbacks) do
		if type(func)=="function" then func(room,player,data,name,result) end
	end
	for row in db:rows("select * from results where id= "..getGameData("roomid")) do
		broadcastMsg(room,"#gainWen",row.wen)
		broadcastMsg(room,"#gainWu",row.wu)
		broadcastMsg(room,"#gainExp",row.expval)
	end

	setGameData("enable",0)
	database2js()
end

-- init ::  :: 更新results, 将所有的 turndata重置为0
-- 
zgfunc[sgs.TurnStart].init=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	addGameData("turncount",1)
	local alive=room:getOwner():isAlive() and 1 or 0
	local kingdom=room:getOwner():getKingdom()
	if kingdom=="god" and getGameData("hegemony")==1 then kingdom=room:getOwner():getGeneral():getKingdom() end
	
	sqlexec("update results set general='%s',kingdom='%s',turncount=%d,alive=%d,wen=wen+%d,wu=wu+%d,expval=expval+%d where id=%d",
			room:getOwner():getGeneralName(),kingdom,getGameData("turncount"), alive,getTurnData("wen"),
			getTurnData("wu"),getTurnData("expval"),getGameData("roomid"))
	for key,val in pairs(zgturndata) do
		zgturndata[key]=0
	end	
	database2js()
end




-- bj :: 暴君 :: 身为主公在1局游戏中，在反贼和内奸全部存活的情况下杀死全部忠臣，并最后胜利
--
zgfunc[sgs.Death].bj=function(self, room, event, player, data,isowner,name)
	local damage = data:toDamageStar()
	if not damage then return false end
	if getGameData("hegemony")==1 then return false end
	if room:getOwner():isLord() and damage.from and damage.from:objectName()==room:getOwner():objectName() 
		and damage.to:getRole()=="loyalist" then
		local players = room:getPlayers()
		local enemy_dead=0,0
		for _, p in sgs.qlist(players) do
			if p:getRole()=="rebel" or p:getRole()=="renegade" then
				if p:isDead() then enemy_dead=enemy_dead+1 end
			end
		end
		if enemy_dead==0 then addGameData(name,1) end
	end		
end


-- bj :: 暴君 :: 身为主公在1局游戏中，在反贼和内奸全部存活的情况下杀死全部忠臣，并最后胜利
-- 
zgfunc[sgs.GameOverJudge].callback.bj=function(room,player,data,name,result)
	if result~='win' then return false end
	if getGameData("hegemony")==1 then return false end
	local loyalistnum=0
	for _,ap in sgs.qlist(room:getPlayers()) do
		if ap:getRole()=="loyalist" then
			if ap:isAlive() then return false
			else
				loyalist_num=loylist_num+1
			end
		end
	end
	if getGameData(name)==loyalist_num then addZhanGong(room,name) end
end


-- bjz :: 败家子 :: 在一局游戏中，弃牌阶段累计弃掉至少10张桃
--
zgfunc[sgs.CardDiscarded].bjz=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	if player:getPhase()~=sgs.Player_Discard then return false end
	local card = data:toCard()
	for _,cdid in sgs.qlist(card:getSubcards()) do
		if sgs.Sanguosha:getCard(cdid):isKindOf("Peach") then
			addGameData(name,1)
		end
	end
	if getGameData(name)==10 then addZhanGong(room,name) end
end


-- bqbr :: 不屈不饶 :: 一格体力情况下，累积出闪100次
--
zgfunc[sgs.CardResponsed].bqbr=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	if player:getHp() == 1 and data:toResponsed().m_card:isKindOf("Jink") then
		addGlobalData(name,1)
		if getGlobalData(name)==100 then addZhanGong(room,name) end
	end
end


-- bqk :: 兵器库 :: 在一局游戏中，累计装备过至少10次武器以及10次防具
--
zgfunc[sgs.CardFinished].bqk=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	local use=data:toCardUse()
	if use.card:isKindOf("Weapon") then
		addGameData(name.."_weapon", 1)
		if getGameData(name.."_weapon")==10 and getGameData(name.."_armor")==10 then addZhanGong(room,name)
	elseif use.card:isKindOf("Armor") then
		addGameData(name.."_armor", 1)
		if getGameData(name.."_weapon")==10 and getGameData(name.."_armor")==10 then addZhanGong(room,name)
	end
end


-- brz :: 百人斩 :: 累积杀死100人
--
zgfunc[sgs.Todo].brz=function(self, room, event, player, data,isowner,name)
	
end


-- cqb :: 拆迁办 :: 在一个回合内使用卡牌过河拆桥/顺手牵羊累计4次
--
zgfunc[sgs.CardFinished].cqb=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	local use = data:toCardUse()
	if use.card:isKindOf("Dismantlement") or use.card:isKindOf("Snatch") then
		addTurnData(name,1)
		if getTurnData(name)==10 then addZhanGong(room,name) end
	end
end


-- cqdd :: 拆迁大队 :: 在一局游戏中，累计使用卡牌过河拆桥10次以上
--
zgfunc[sgs.CardFinished].cqdd=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	local use = data:toCardUse()
	if use.card:isKindOf("Dismantlement") then
		addGameData(name,1)
		if getGameData(name)==10 then addZhanGong(room,name) end
	end
end


-- dxgl :: 东西宫略 :: 在一局游戏中，身份为男性主公，而忠臣为两名女性武将并获胜
--
zgfunc[sgs.GameOverJudge].callback.dxgl=function(room,player,data,name,result)
	if getGameData("hegemony")==1 then return false end
	local female_loyalist = 0
	for _,op in sgs.qlist(room:getPlayers()) do
		if op:getRole()=="loyalist" and op:isFemale() then
			female_loyalist = female_loyalist+1
		end
	end
	if result =='win' and room:getOwner():isLord() and room:getOwner():isMale() and female_loyalist>=2 then addZhanGong(room,name) end
end


-- gjcc :: 诡计重重 :: 在一局游戏中，累计使用锦囊牌至少20次
--
zgfunc[sgs.CardFinished].gjcc=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	local use = data:toCardUse()
	if use.card:isKindOf("TrickCard") then 
		addGameData(name,1)
		if getGameData(name)==20 then addZhanGong(room,name) end
	end
	
end


-- gn :: 果农 :: 游戏开始时，起手4张“桃”
--
zgfunc[sgs.GameStart].gn=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	local peach_num=0
	for _,cd in sgs.qlist(player:getHandcards()) do
		if cd:isKindOf("Peach") then peach_num=peach_num+1 end
	end
	if peach_num == 4 then addZhanGong(room,name) end
end


-- htdl :: 黄天当立 :: 使用张角在一局游戏中通过黄天得到的闪不少于8张
--
zgfunc[sgs.CardEffected].htdl=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	if player:getGeneralName()~="zhangjiao" then return false end
	local effect=data:toCardEffect()
	if effect.card:isKindOf("HuangtianCard") and effect.card:getSubcards():first():isKindOf("Jink") then
		addGameData(name,1)
		if getGameData(name)==8 then addZhanGong(room,name)
	end
end


-- jdfy :: 绝对防御 :: 在一局游戏中，使用八挂累计出闪20次
--
zgfunc[sgs.CardResponsed].jdfy=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	if data:toResponsed().m_card:isKindOf("Jink") and data:toResponsed().m_card:getSkillName()=="EightDiagram" then
		addGameData(name,1)
		if getGameData(name)==20 then addZhanGong(room,name) end
	end
end


-- jg :: 酒鬼 :: 出牌阶段开始时，手牌中至少有3张“酒”
--
zgfunc[sgs.EventPhaseStart].jg=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	if player:getPhase()==sgs.Player_Play and player:getHandcardNum()>2 then
		local analeptic_num=0
		for _,cd in sgs.qlist(player:getHandcard()) do
			if cd:isKindOf("Analeptic") then
				analeptic_num=analeptic_num+1
			end
		end
		if analeptic_num>=3 then addZhanGong(room,name) end
	end
end


-- jhlt :: 举火燎天 :: 在一局游戏中，造成火焰伤害累计10点以上，不含武将技能
--
zgfunc[sgs.Damage].jhlt=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	local damage=data:toDamage()
	if damage.card~=nil and damage.nature==sgs.DamageStruct_Fire then
		addGameData(name,damage.damage)
		if getGameData(name)>=10 then 
			addZhanGong(room,name) 
			setGameData(name, -100)
		end
	end
end


-- qrz :: 千人斩 :: 累积杀1000人
--
zgfunc[sgs.Todo].qrz=function(self, room, event, player, data,isowner,name)
	
end


-- qshs :: 起死回生 :: 在一局游戏中，累计受过至少20点伤害且最后存活获胜
--
zgfunc[sgs.Damaged].qshs=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	addGameData(name, damage.damage)
end


-- qshs :: 起死回生 :: 在一局游戏中，累计受过至少20点伤害且最后存活获胜
--
zgfunc[sgs.GameOverJudge].callback.qshs=function(room,player,data,name,result)
	if getGameData(name)>=20 and result=='win' and room:getOwner():isAlive() then addZhanGong(room,name) end
end


-- stzs :: 神偷再世 :: 在一局游戏中，累计使用卡牌顺手牵羊10次以上
--
zgfunc[sgs.CardFinished].stzs=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	local use = data:toCardUse()
	if use.card:isKindOf("Snatch") then
		addGameData(name,1)
		if getGameData(name)==10 then addZhanGong(room,name) end
	end
end


-- thy :: 桃花运 :: 当你的开局4牌全部为红桃时，体力上限加1
--
zgfunc[sgs.GameStart].thy=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	local heart_num=0
	if player:getHandcardNum()~=4 then return false end
	for _,cd in sgs.qlist(player:getHandcards()) do
		if cd:getSuit()==sgs.Card_Heart then heart_num=heart_num+1 end
	end
	if heart_num == 4 then 
		addZhanGong(room,name) 
		room:setPlayerProperty(player, "maxhp", sgs.QVariant(player:getMaxHp()+1))
	end
end


-- tyzy :: 桃园之义 :: 在一局游戏中，场上同时存在刘备、关羽、张飞三人且为队友，而你是其中一个并最后获胜
--
zgfunc[sgs.GameOverJudge].callback.tyzy=function(room,player,data,name,result)
	if result~='win' then return false end
	local has_liubei,has_guanyu,has_zhangfei,issjy=false,false,false,false
	function isTeammate(room,a,b)
		if getGameData("hegemony")==1 then
			return a:getKingdom()==b:getKingdom()
		else
			local ar=a:getRole()
			local br=b:getRole()
			if ar=="lord" or ar=="loyalist" then ar=="lord+loyalist" end
			if br=="lord" or ar=="loyalist" then br=="lord+loyalist" end
			if room:getMode()=='06_3v3' then				
				if ar=="rebel" or ar=="renegade" then ar=="rebel+renegade" end
				if br=="rebel" or br=="renegade" then br=="rebel+renegade" end
			end
			return ar==br
		end
	end
	local owner = room:getOwner()
	for _,ap in sgs.qlist(room:getPlayers()) do
		if isTeammate(room,owner,ap) then
			local gname = ap:getGeneralName()
			if gname=="liubei" or gname=="bgm_liubei" then
				has_liubei=true
				if owner:objectName()==ap:objectName() then issjy==true
			elseif gname=="guanyu" or gname=="shenguanyu" or gname=="sp_guanyu" or gname=="neo_guanyu" then
				has_guanyu=true
				if owner:objectName()==ap:objectName() then issjy==true
			elseif gname=="zhangfei" or gname=="neo_zhangfei" or gname=="bgm_zhangfei" then
				has_zhangfei=true
				if owner:objectName()==ap:objectName() then issjy==true
			end
		end
	end
	if has_liubei and has_zhangfei and has_zhangfei and issjy then
		addZhanGong(room, name)
	end
end


-- wabm :: 唯爱不灭 :: 使用任意武将在一局游戏中被步练师发动过追忆并最后获胜。
--
zgfunc[sgs.Todo].wabm=function(self, room, event, player, data,isowner,name)
	
end


-- wsww :: 为时未晚 :: 身为反贼，在一局游戏中杀死了除自己以外所有反贼并获得游戏的胜利
--
zgfunc[sgs.Death].wsww=function(self, room, event, player, data,isowner,name)
	local damage = data:toDamageStar()
	if not damage then return false end
	if getGameData("hegemony")==1 then return false end
	if room:getOwner():getRole=="rebel" and damage.from and damage.from:objectName()==room:getOwner():objectName() 
		and damage.to:getRole()=="rebel" then
		addGameData(name,1)
	end	
end


-- wsww :: 为时未晚 :: 身为反贼，在一局游戏中杀死了除自己以外所有反贼并获得游戏的胜利
--
zgfunc[sgs.GameOverJudge].callback.wsww=functionfunction(room,player,data,name,result)
	if result~='win' then return false end
	if getGameData("hegemony")==1 then return false end
	local rebel_num=0
	for _,ap in sgs.qlist(room:getPlayers()) do
		if ap:getRole()=="rebel" then
			if ap:isAlive() then return false
			else
				rebel_num=rebel_num+1
			end
		end
	end
	if getGameData(name)==rebel_num then addZhanGong(room,name) end
end


-- xcdz :: 星驰电走 :: 在一局游戏中，累计出闪20次
--
zgfunc[sgs.Todo].xcdz=function(self, room, event, player, data,isowner,name)
	if data:toResponsed().m_card:isKindOf("Jink") then
		addGameData(name,1)
		if getGameData(name)==20 then addZhanGong(room,name) end
	end
end


-- xhjs :: 悬壶济世 :: 在一局游戏中，使用桃或技能累计将我方队友脱离濒死状态4次以上
--
zgfunc[sgs.HpRecover].xhjs=function(self, room, event, player, data,isowner,name)
	local recover = data:toRecover()
	if recover.recover>=player:getHp() and recover.who:objectName()==room:getOwner():objectName() then
		addGameData(name,1)
		if getGameData(name)==4 then addZhanGong(room,name)
end


-- xnhx :: 邪念惑心 :: 作为忠臣在一局游戏中，在场上没有反贼时手刃主公
--
zgfunc[sgs.Todo].xnhx=function(self, room, event, player, data,isowner,name)
	
end


-- ymds :: 驭马大师 :: 在一局游戏中，至少更换过6匹马
--
zgfunc[sgs.Todo].ymds=function(self, room, event, player, data,isowner,name)
	
end


-- cqcz :: 此情常在 :: 在一局游戏中，布练师发动安恤4次并在阵亡情况下获胜
--
zgfunc[sgs.Todo].cqcz=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='bulianshi' then return false end
end


-- ctbc :: 拆桃不偿 :: 使用甘宁在一局游戏中发动“奇袭”拆掉至少5张桃
--
zgfunc[sgs.Todo].ctbc=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='ganning' then return false end
end


-- dkjj :: 荡寇将军 :: 使用程普在一局游戏中，发动技能“疠火”杀死至少三名反贼最终获得胜利
--
zgfunc[sgs.Todo].dkjj=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='chengpu' then return false end
end


-- fpz :: 方片周 :: 使用周瑜在一局游戏中累计4次反间都被对方猜中并拿走方片手牌
--
zgfunc[sgs.Todo].fpz=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='zhouyu' then return false end
end


-- gzwb :: 固政为本 :: 使用张昭张纮在一局游戏中利用技能“固政”获得雷击至少40张牌
--
zgfunc[sgs.Todo].gzwb=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='erzhang' then return false end
end


-- jfhz :: 解烦护主 :: 使用韩当在一局游戏游戏中发动“解烦”救过队友孙权至少两次
--
zgfunc[sgs.Todo].jfhz=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='handang' then return false end
end


-- jjh :: 交际花 :: 使用孙尚香和全部其他角色皆使用过结姻
--
zgfunc[sgs.Todo].jjh=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='sunshangxiang' then return false end
end


-- jjnh :: 禁军难护 :: 使用韩当在一局游戏中有角色濒死时发动“解烦”并出杀后均被闪避至少5次
--
zgfunc[sgs.Todo].jjnh=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='handang' then return false end
end


-- jwrs :: 军威如山 :: 使用☆SP甘宁在一局游戏中发动军威累计得到过至少6张“闪”
--
zgfunc[sgs.Todo].jwrs=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='bgm_ganning' then return false end
end


-- jyh :: 解语花 :: 使用步练师在一局游戏中发动安恤摸八张牌以上
--
zgfunc[sgs.Todo].jyh=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='bulianshi' then return false end
end


-- pjzs :: 破军之势 :: 使用徐盛在一局游戏中发动“破军”让一名角色连续翻面3次
--
zgfunc[sgs.Todo].pjzs=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='xusheng' then return false end
end


-- ssex :: 三思而行 :: 使用孙权在一局游戏中利用制衡获得至少4张无中生有以及4张桃
--
zgfunc[sgs.Todo].ssex=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='sunquan' then return false end
end


-- sssl :: 深思熟虑 :: 使用孙权在一个回合内发动制衡的牌不少于10张
--
zgfunc[sgs.Todo].sssl=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='sunquan' then return false end
end


-- syjh :: 岁月静好 :: 使用☆SP大乔在一局游戏中发动安娴五次并获胜
--
zgfunc[sgs.Todo].syjh=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='bgm_daqiao' then return false end
end


-- xxf :: 小旋风 :: 使用凌统在一局游戏中发动技能“旋风”弃掉其他角色累计15张牌
--
zgfunc[sgs.Todo].xxf=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='lingtong' then return false end
end


-- ynnd :: 有难你当 :: 使用小乔在一局游戏中发动“天香”导致一名其他角色死亡
--
zgfunc[sgs.Todo].ynnd=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='xiaoqiao' then return false end
end


-- dkzz :: 杜康之子 :: 使用曹植在一局游戏中发动酒诗后成功用杀造成伤害累计5次
--
zgfunc[sgs.Todo].dkzz=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='caozhi' then return false end
end


-- dqzw :: 大权在握 :: 使用钟会在一局游戏中有超过8张权
--
zgfunc[sgs.Todo].dqzw=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='zhonghui' then return false end
end


-- dym :: 大姨妈 :: 使用甄姬连续5回合洛神的第一次结果都是红色，不包括改判
--
zgfunc[sgs.Todo].dym=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='zhenji' then return false end
end


-- fynd :: 愤勇难当 :: 使用☆SP夏侯惇在一局游戏中，至少发动四次奋勇
--
zgfunc[sgs.Todo].fynd=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='bgm_xiahoudun' then return false end
end


-- glnc :: 刚烈难存 :: 使用夏侯惇在一局游戏中连续4次刚烈判定均为红桃
--
zgfunc[sgs.Todo].glnc=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='xiahoudun' then return false end
end


-- jcyd :: 将驰有度 :: 使用曹彰发动将驰的两种效果各连续两回合
--
zgfunc[sgs.Todo].jcyd=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='caozhang' then return false end
end


-- jdqb :: 经达权变 :: 使用荀攸在一局游戏中，至少发动三次智愚弃掉对手手牌
--
zgfunc[sgs.Todo].jdqb=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='xunyou' then return false end
end


-- jsbc :: 坚守不出 :: 使用曹仁在一局游戏中连续6回合发动据守
--
zgfunc[sgs.Todo].jsbc=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='caoren' then return false end
end


----------------------------------------------------------------------------
----------------------------------------------------------------------------
-----------分割线
----------------------------------------------------------------------------
----------------------------------------------------------------------------


-- lrhj :: 来人，护驾 :: 使用曹操在一局游戏中发动护驾累计被响应不少于10次
--
zgfunc[sgs.Todo].lrhj=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='caocao' then return false end
end


-- qbcs :: 七步成诗 :: 使用曹植在一局游戏中发动酒诗7次
--
zgfunc[sgs.Todo].qbcs=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='caozhi' then return false end
end


-- qjbc :: 奇计百出 :: 使用荀攸在一局游戏中，发动“奇策”使用至少六种锦囊
--
zgfunc[sgs.Todo].qjbc=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='xunyou' then return false end
end


-- qmjj :: 奇谋九计 :: 使用王异在一局游戏中至少成功发动九次秘计并获胜。
--
zgfunc[sgs.Todo].qmjj=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='wangyi' then return false end
end


-- qqtx :: 权倾天下 :: 使用钟会在一局游戏中发动“排异”累计摸牌至少10张
--
zgfunc[sgs.Todo].qqtx=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='zhonghui' then return false end
end


-- tmnw :: 天命难违 :: 使用司马懿被自己挂的闪电劈死，不包括改判
--
zgfunc[sgs.Todo].tmnw=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='simayi' then return false end
end


-- tmzf :: 天命之罚 :: 在一局游戏中，使用司马懿更改闪电判定牌至少劈中其他角色两次
--
zgfunc[sgs.Todo].tmzf=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='simayi' then return false end
end


-- wzxj :: 稳重行军 :: 使用于禁在一局游戏中发动“毅重”抵御至少4次黑色杀
--
zgfunc[sgs.Todo].wzxj=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='yujin' then return false end
end


-- xhdc :: 雪痕敌耻 :: 使用☆SP夏侯惇在一局游戏中，发动雪痕杀死一名角色
--
zgfunc[sgs.Todo].xhdc=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='bgm_xiahoudun' then return false end
end


-- xzxm :: 先知续命 :: 使用郭嘉在一局游戏中利用技能“天妒”收进至少4个桃
--
zgfunc[sgs.Todo].xzxm=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='guojia' then return false end
end


-- ybyt :: 义薄云天 :: 使用SP关羽在觉醒后杀死两个反贼并最后获胜
--
zgfunc[sgs.Todo].ybyt=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='sp_guanyu' then return false end
end


-- ajnf :: 暗箭难防 :: 使用马岱在一局游戏中发动“潜袭”成功至少6次
--
zgfunc[sgs.Todo].ajnf=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='madai' then return false end
end


-- cbhw :: 长坂虎威 :: 使用张飞在一回合内使用8张杀
--
zgfunc[sgs.Todo].cbhw=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='zhangfei' then return false end
end


-- cbyx :: 长坂英雄 :: 使用赵云在一局游戏中，在刘禅为队友且存活情况下获胜
--
zgfunc[sgs.Todo].cbyx=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='zhaoyun' then return false end
end


-- dcxj :: 雕虫小技 :: 使用卧龙在一局游戏中发动“看破”至少15次
--
zgfunc[sgs.Todo].dcxj=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='wolong' then return false end
end


-- dyzh :: 当阳之吼 :: 在一局游戏中，使用☆SP张飞累计两次在大喝拼点成功的回合中用红“杀”手刃一名角色
--
zgfunc[sgs.Todo].dyzh=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='bgm_zhangfei' then return false end
end


-- gmzc :: 过目之才 :: 使用☆SP庞统一回合内累计拿到至少16张牌
--
zgfunc[sgs.Todo].gmzc=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='bgm_pangtong' then return false end
end


-- hlzms :: 挥泪斩马谡 :: 使用诸葛亮杀死马谡
--
zgfunc[sgs.Todo].hlzms=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='zhugeliang' then return false end
end


-- hztx :: 虎子同心 :: 使用关兴张苞在父魂成功后，一个回合杀死至少三名反贼
--
zgfunc[sgs.Todo].hztx=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='guanxingzhangbao' then return false end
end


-- rxbz :: 仁心布众 :: 使用刘备在一局游戏中，累计仁德至少30张牌
--
zgfunc[sgs.Todo].rxbz=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='liubei' then return false end
end


-- wxwd :: 惟贤惟德 :: 使用刘备在一个回合内发动仁德给的牌不少于10张
--
zgfunc[sgs.Todo].wxwd=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='liubei' then return false end
end


-- wyyd :: 无言以对 :: 使用徐庶在一局游戏中发动“无言”躲过南蛮入侵或万箭齐发雷击4次
--
zgfunc[sgs.Todo].wyyd=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='xushu' then return false end
end


-- xlwzy :: 星落五丈原 :: 使用诸葛亮，在司马懿为敌方时阵亡
--
zgfunc[sgs.Todo].xlwzy=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='zhugeliang' then return false end
end


-- ysadj :: 以死安大局 :: 使用马谡在一局游戏中发动“挥泪”使一名角色弃置8张牌
--
zgfunc[sgs.Todo].ysadj=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='masu' then return false end
end


-- zlzn :: 昭烈之怒 :: 在一局游戏中，使用☆SP刘备发动昭烈杀死至少2人
--
zgfunc[sgs.Todo].zlzn=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='bgm_liubei' then return false end
end


-- zmjzg :: 走马见诸葛 :: 使用徐庶在一局游戏中至少有3次举荐诸葛且用于举荐的牌里必须有马
--
zgfunc[sgs.Todo].zmjzg=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='xushu' then return false end
end


-- zzhs :: 智之化身 :: 使用黄月英在一局游戏发动20次集智至少20次
--
zgfunc[sgs.Todo].zzhs=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='huangyueying' then return false end
end


-- bnzw :: 暴虐之王 :: 使用董卓在一局游戏中利用技能“暴虐”至少回血10次
--
zgfunc[sgs.Todo].bnzw=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='dongzhuo' then return false end
end


-- hjqy :: 黄巾起义 :: 使用张角在一局游戏中收到过群雄角色给的闪至少3张，发动至少3次雷击并击中对方
--
zgfunc[sgs.Todo].hjqy=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='zhangjiao' then return false end
end


-- jjqj :: 进谏劝君  :: 使用陈宫在一局游戏中，对主公发动“明策”，令主公摸至少5张牌
--
zgfunc[sgs.Todo].jjqj=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='chengong' then return false end
end


-- jjyb :: 戒酒以备 :: 使用高顺在一局游戏中使用技能“禁酒”将至少3张酒当成杀使用或打出
--
zgfunc[sgs.Todo].jjyb=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='gaoshun' then return false end
end


-- pjbl :: 片甲不留 :: 对一名角色发动猛进后导致其空城且装备区为空
--
zgfunc[sgs.Todo].pjbl=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='pangde' then return false end
end


-- qldy :: 枪林弹雨 :: 使用袁绍在一回合内发动8次乱击
--
zgfunc[sgs.Todo].qldy=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='yuanshao' then return false end
end


-- sbfs :: 生不逢时 :: 使用双雄对关羽使用决斗，并因这个决斗被关羽杀死
--
zgfunc[sgs.Todo].sbfs=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='yanliangwenchou' then return false end
end


-- syqd :: 恃勇轻敌 :: 使用华雄在一局游戏中，在没有马岱在场的情况下由于体力上限减至0而死亡
--
zgfunc[sgs.Todo].syqd=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='huaxiong' then return false end
end


-- yzrx :: 医者仁心 :: 使用华佗在一局游戏中对4个身份的人都发动过青囊，游戏结束亮明身份后获得
--
zgfunc[sgs.Todo].yzrx=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='huatuo' then return false end
end


-- zsbsh :: 宗室遍四海 :: 使用刘表在一局游戏中利用技能“宗室”提高4手牌上限
--
zgfunc[sgs.Todo].zsbsh=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='liubiao' then return false end
end


-- cbyh :: 赤壁业火 :: 使用神周瑜发动业炎造成10点或更多的火焰伤害
--
zgfunc[sgs.Todo].cbyh=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='shenzhouyu' then return false end
end


-- gqzl :: 顾曲周郎 :: 使用神周瑜连续至少4回合发动琴音回复体力
--
zgfunc[sgs.Todo].gqzl=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='shenzhouyu' then return false end
end


-- jjfs :: 绝境逢生 :: 使用神赵云在一局游戏中一直为一滴血的情况下并获胜
--
zgfunc[sgs.Todo].jjfs=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='shenzhaoyun' then return false end
end


-- lpkd :: 连破克敌 :: 使用神司马懿在一局游戏中发动3次连破并最后获胜
--
zgfunc[sgs.Todo].lpkd=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='shensimayi' then return false end
end


-- sfgj :: 三分归晋 :: 使用神司马懿杀死刘备，孙权，曹操各累计10次
--
zgfunc[sgs.Todo].sfgj=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='shensimayi' then return false end
end


-- shgx :: 四海归心 :: 使用神曹操在一局游戏中受到2点伤害之后发动2次归心
--
zgfunc[sgs.Todo].shgx=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='shencaocao' then return false end
end


-- swzs :: 神威之势 :: 使用神赵云发动各花色龙魂各两次并在存活的情况下取得游戏胜利
--
zgfunc[sgs.Todo].swzs=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='shenzhaoyun' then return false end
end


-- tyzm :: 桃园之梦 :: 使用神关羽在一局游戏中阵亡后发动武魂判定结果为桃园结义
--
zgfunc[sgs.Todo].tyzm=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='shenguanyu' then return false end
end


-- wmsz :: 无谋竖子 :: 使用神吕布在一局游戏中发动无谋至少6次
--
zgfunc[sgs.Todo].wmsz=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='shenlvbu' then return false end
end


-- yrbf :: 隐忍不发 :: 使用神司马懿在一局游戏中发动忍戒至少10次并获胜
--
zgfunc[sgs.Todo].yrbf=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='shensimayi' then return false end
end


-- zszn :: 战神之怒 :: 使用神吕布在一局游戏中发动至少4次神愤、3次无前
--
zgfunc[sgs.Todo].zszn=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='shenlvbu' then return false end
end






function broadcastMsg(room,info,...)
	local log= sgs.LogMessage()
	log.type = info
	log.from = room:getOwner()
	if #arg>0 then log.arg = arg[1] end
	if #arg>1 then log.arg2 =arg[2] end
	room:sendLog(log)
	return true
end

function addZhanGong(room,name)
	sqlexec("update zhangong set gained=gained+1,lasttime=datetime('now','localtime') where id='%s'",name)
	setGameData("myzhangong", getGameData("myzhangong","")..name..":")
	sqlexec("update results set zhangong='%s' where id='%d'",getGameData("myzhangong",""),getGameData("roomid"))
	broadcastMsg(room,"#zhangong_"..name)	
	room:getOwner():speak(string.format("恭喜获得战功【<font color='yellow'><b>%s</b></font>】",sgs.Sanguosha:translate(name)))
	database2js()
end

--[[
	GlobalData  永久保存到数据库中的数据
	用于保存类似， 被南蛮入侵打死N次， 3v3前锋被主帅打死N次等类似战功的数据存储
]]
function addGlobalData(key,val)
	getGlobalData(key)
	sqlexec("update gamedata set num=num+%d where id='%s'",val,key)
end

function setGlobalData(key,val)	
	getGlobalData(key)
	sqlexec("update gamedata set num=%d where id='%s'",val,key)
end

function getGlobalData(key,...)
	local defval= #arg>=1 and arg[1] or 0
	local row=db:first_row(string.format("select id,num from gamedata where id='%s'",key))
	if (not row) or row.id==nil then
		sqlexec("insert into gamedata values('%s',0)",key)
		return defval
	else
		return row.num
	end
end

--[[
	GameData  某盘游戏的全局变量
	游戏开始时，GameData变量清0，游戏结束后，GameData变量的数据消失	
]]
function addGameData(key,val)
	if not zggamedata[key] then zggamedata[key]=0 end
	zggamedata[key]=zggamedata[key]+val
end

function setGameData(key,val)	
	zggamedata[key]=val
end

function getGameData(key,...)
	if not zggamedata[key] then return #arg>=1 and arg[1] or 0 end
	return zggamedata[key]
end


--[[
	TurnData  回合变量
	房主每一个回合开始时，所有TurnData变量清0，	
]]
function addTurnData(key,val)
	if not zgturndata[key] then zgturndata[key]=0 end
	zgturndata[key]=zgturndata[key]+val
end

function setTurnData(key,val)
	zgturndata[key]=val
end

function getTurnData(key,...)
	if not zgturndata[key] then return #arg>=1 and arg[1] or 0 end
	return zgturndata[key]
end



function init_gamestart(self, room, event, player, data, isowner)
	local config=sgs.Sanguosha:getSetupString():split(":")
	local mode=config[2]
	local flags=config[5]
	local owner=room:getOwner()

	if not isowner or getGameData("enable")==1 then return false end

	--[[
	if  not string.find(mode,"^[01]%d[p_]") or string.find(flags,"[F]") then
		setGameData("enable",0)
		return false
	end
	]]

	local count=0
	for _, p in sgs.qlist(room:getAllPlayers()) do
		if p:getState() ~= "robot" then 
			count=count+1
			room:acquireSkill(p,"rende")
			room:acquireSkill(p,"zhijian")
			room:acquireSkill(p,"guicai")
			room:acquireSkill(p,"qixi")
			room:acquireSkill(p,"paoxiao")
			room:acquireSkill(p,"shenwei")
		else
			room:detachSkillFromPlayer(p, "#zgzhangong1")
			room:detachSkillFromPlayer(p, "#zgzhangong2")
		end
	end
	if count>1 then
		setGameData("enable",0)
		return false
	end

	for key,val in pairs(zggamedata) do
		zggamedata[key]=0
	end

	setGameData("enable",1)
	setGameData("myzhangong","")
	if string.find(flags,"H") then setGameData("hegemony",1) end

	if getGameData("roomid")==0 then 
		setGameData("roomid",os.time())
		setTurnData("wen",0)
		setTurnData("wu",0)
		setTurnData("expval",0)
		sqlexec("insert into results values(%d,'%s','%s','%s','%d','%s',0,1,'-',0,0,0,'')",
				getGameData("roomid"),player:getGeneralName(),player:getRole(),
				player:getKingdom(),getGameData("hegemony"),room:getMode())
	end	

	return true
end


zgzhangong1 = sgs.CreateTriggerSkill{
	name = "#zgzhangong1",
	events = {sgs.GameStart,sgs.Damage,sgs.GameOverJudge,sgs.Death,sgs.DamageCaused,sgs.DamageComplete,
			sgs.TurnStart,sgs.HpRecover,sgs.DamageInflicted,sgs.ConfirmDamage,sgs.Damaged},
	priority = 6,
	can_trigger = function()
		return true
	end,

	on_trigger = function(self, event, player, data)
		local room = player:getRoom()
		local owner= room:getOwner():objectName()==player:objectName()
		
		if event ==sgs.GameStart and owner and room:getTag("zg_init_game"):toBool()==false then
			room:setTag("zg_init_game",sgs.QVariant(true))
			local log= sgs.LogMessage()
				if init_gamestart(self, room, event, player, data, owner) then
				log.type = "#enableZhangong"
			else
				log.type = "#disableZhangong"
			end
			room:sendLog(log)
		end

		local callbacks=zgfunc[event]
		if callbacks and getGameData("enable")==1 then
			for name, func in pairs(callbacks) do
				if type(func)=="function" then 						
					func(self, room, event, player, data, owner,name) 
				end				
			end
		end
		return false
	end,
}

zgzhangong2 = sgs.CreateTriggerSkill{
	name = "#zgzhangong2",
	events = {sgs.CardFinished,sgs.ChoiceMade,sgs.EventPhaseStart,sgs.EventPhaseEnd,sgs.Pindian,sgs.CardEffect,
		sgs.CardEffected,sgs.SlashEffected,sgs.SlashEffect,sgs.CardsMoveOneTime,sgs.FinishRetrial,
		sgs.CardDiscarded,sgs.CardResponsed},
	priority = 6,
	on_trigger = function(self, event, player, data)
		local room = player:getRoom()
		local owner= room:getOwner():objectName()==player:objectName()

		local callbacks=zgfunc[event]
		if callbacks and getGameData("enable")==1 then
			for name, func in pairs(callbacks) do
				if type(func)=="function" then 						
					func(self, room, event, player, data, owner,name) 
				end				
			end
		end
		return false
	end,
}


function getWinner(room,victim)
	local mode=room:getMode()
	local role=victim:getRole()

	if mode == "02_1v1" then
		local list = victim:getTag("1v1Arrange"):toStringList()		
		if #list >0  then return false end
	end

	local alives=sgs.QList2Table(room:getAlivePlayers())
	
	if getGameData("hegemony")==1 then				
        local has_anjiang = false
		local has_diff_kingdoms = false
        local init_kingdom
		for _, p in sgs.qlist(room:getAlivePlayers()) do
			if room:getTag(p:objectName()):toString()~="" then 
				has_anjiang = true
            end
            if init_kingdom == nil then 
                init_kingdom = p:getKingdom()
            elseif init_kingdom ~= p:getKingdom() then
                has_diff_kingdoms = true
            end
		end

        if not has_anjiang and  not has_diff_kingdoms then
            local winners={}
			local aliveKingdom = alives[1]:getKingdom()

            for _, p in sgs.qlist(room:getAllPlayers()) do
                if p:isAlive() then 
					table.insert(winners , p:objectName()) 
				else
					if p:getKingdom() == aliveKingdom then
						local generals = room:getTag(p:objectName()):toString()
						if (not (generals and not string.find(flags,"S"))) or (not string.find(generals,",")) then
							table.insert(winners , p:objectName())
						end
					end
				end
            end
            return #winners and table.concat(winners,"+") or false
        end	
	end
	
	
	if mode == "06_3v3" then
		if role=="lord" then return "renegade+rebel" end
		if role=="renegade" then return "lord+loyalist" end
		return false			
	else
		local alive_roles = room:aliveRoles(victim)
		if role=="lord" then
			return #alives==1 and alives[1]:getRole()== "renegade" and alives[1]:objectName() or "rebel"
		elseif role=="rebel" or role=="renegade" then
			local alive_roles_str = table.concat(alive_roles,",")
			if (not string.find(alive_roles_str,"rebel")) and (not string.find(alive_roles_str,"renegade")) then
				return "lord+loyalist"
			end
		end
	end
	return false
end

function initZhangong()
	local generalnames=sgs.Sanguosha:getLimitedGeneralNames()
	local packages={}
	for _, pack in ipairs(config.package_names) do
		if pack=="NostalGeneral" then table.insert(packages,"nostal_general") end
		table.insert(packages,string.lower(pack))
	end
	local hidden={"sp_diaochan","sp_sunshangxiang","sp_pangde","sp_caiwenji","sp_machao","sp_jiaxu","anjiang","shenlvbu1","shenlvbu2"}
	table.insertTable(generalnames,hidden)
	for _, generalname in ipairs(generalnames) do
		local general = sgs.Sanguosha:getGeneral(generalname)
		if general then
			local packname = string.lower(general:getPackage())		
			if table.contains(packages,packname) then
				general:addSkill("#zgzhangong1")
				general:addSkill("#zgzhangong2")
			end
		end
	end
end

zganjiang:addSkill(zgzhangong1)
zganjiang:addSkill(zgzhangong2)
initZhangong()


function genTranslation()
	local zgTrList={}	
	for row in db:rows("select id,name,description from zhangong") do
		zgTrList["#zhangong_"..row.id]="%from 获得了战功【<b><font color='yellow'>"..row.name.."</font></b>】,"..row.description
		zgTrList[row.id]=row.name
	end
	return zgTrList
end


sgs.LoadTranslationTable(genTranslation())

sgs.LoadTranslationTable {
	["zhangong"] ="战功包",
	["#gainWen"] ="%from获得【%arg】点文功",
	["#gainWu"] ="%from获得【%arg】点武功",
	["#gainExp"] ="%from获得【%arg】点经验",
	["#enableZhangong"]="【<b><font color='green'>提示</font></b>】: 本局游戏开启了战功统计",
	["#disableZhangong"]="【<b><font color='red'>提示</font></b>】: 本局游戏禁止了战功统计",	
}
