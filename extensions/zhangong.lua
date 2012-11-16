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
zgfunc[sgs.CardResponsed]={}


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
zgfunc[sgs.HpChanged]={}

zgfunc[sgs.SlashEffect]={}
zgfunc[sgs.SlashEffected]={}
zgfunc[sgs.SlashMissed]={}

zgfunc[sgs.TurnStart]={}
zgfunc[sgs.Pindian]={}
zgfunc[sgs.Predamage]={}

sgs.Todo=9999
zgfunc[sgs.Todo]={}

myroom=nil

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
	if result~='win' or not room:getOwner():isLord() then return false end
	if getGameData("hegemony")==1 then return false end
	local loyalist_num=0
	for _,ap in sgs.qlist(room:getPlayers()) do
		if ap:getRole()=="loyalist" then
			if ap:isAlive() then return false
			else
				loyalist_num=loyalist_num+1
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
			if getGameData(name)==10 then addZhanGong(room,name) end
		end
	end
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
		if getGameData(name.."_weapon")>=10 and getGameData(name.."_armor")>=10 then
			addZhanGong(room,name)
			setGameData(name.."_weapon", -100)
		end
	elseif use.card:isKindOf("Armor") then
		addGameData(name.."_armor", 1)
		if getGameData(name.."_weapon")>=10 and getGameData(name.."_armor")>=10 then
			addZhanGong(room,name)
			setGameData(name.."_armor", -100)
		end
	end
end


-- brz :: 百人斩 :: 累积杀死100人
--
zgfunc[sgs.Death].brz=function(self, room, event, player, data,isowner,name)
	local damage=data:toDamageStar()
	if damage and damage.from and damage.from:objectName()==room:getOwner():objectName() then
		addGlobalData(name,1)
		if getGlobalData(name)==100 then addZhanGong(room,name) end
	end
end


zgfunc[sgs.GameOverJudge].callback.brz=function(room,player,data,name,result)
	local damage=data:toDamageStar()
	if damage and damage.from and damage.from:objectName()==room:getOwner():objectName() then
		addGlobalData(name,1)
		if getGlobalData(name)==100 then addZhanGong(room,name) end
	end
end


-- cqb :: 拆迁办 :: 在一个回合内使用卡牌过河拆桥/顺手牵羊累计4次
--
zgfunc[sgs.CardFinished].cqb=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	local use = data:toCardUse()
	if use.card:isKindOf("Dismantlement") or use.card:isKindOf("Snatch") then
		addTurnData(name,1)
		if getTurnData(name)==4 then addZhanGong(room,name) end
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


-- dgxl :: 东宫西略 :: 在一局游戏中，身份为男性主公，而忠臣为两名女性武将并在女性忠臣全部存活的情况下获胜
--
zgfunc[sgs.GameOverJudge].callback.dxgl=function(room,player,data,name,result)
	if getGameData("hegemony")==1 then return false end
	local female_loyalist = 0
	local female_loyalist_alive = true
	for _,op in sgs.qlist(room:getPlayers()) do
		if op:getRole()=="loyalist" and op:isFemale() then
			female_loyalist = female_loyalist+1
			if not op:isAlive() then female_loyalist_alive = false end
		end
	end
	if result =='win' and room:getOwner():isLord() and room:getOwner():isMale()
			and female_loyalist>=2 and female_loyalist_alive then
		addZhanGong(room,name)
	end
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
	if effect.card:isKindOf("HuangtianCard") and sgs.Sanguosha:getCard(effect.card:getSubcards():first()):isKindOf("Jink") then
		addGameData(name,1)
		if getGameData(name)==8 then addZhanGong(room,name) end
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
		for _,cd in sgs.qlist(player:getHandcards()) do
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
	if damage and damage.card and damage.nature==sgs.DamageStruct_Fire then
		addGameData(name,damage.damage)
		if getGameData(name)>=10 then 
			addZhanGong(room,name) 
			setGameData(name, -100)
		end
	end
end


-- qrz :: 千人斩 :: 累积杀1000人
--
zgfunc[sgs.Death].qrz=function(self, room, event, player, data,isowner,name)
	local damage=data:toDamageStar()
	if damage and damage.from and damage.from:objectName()==room:getOwner():objectName() then
		addGlobalData(name,1)
		if getGlobalData(name)==1000 then addZhanGong(room,name) end
	end
end


zgfunc[sgs.GameOverJudge].callback.qrz=function(room,player,data,name,result)
	local damage=data:toDamageStar()
	if damage and damage.from and damage.from:objectName()==room:getOwner():objectName() then
		addGlobalData(name,1)
		if getGlobalData(name)==1000 then addZhanGong(room,name) end
	end
end


-- qshs :: 起死回生 :: 在一局游戏中，累计受过至少20点伤害且最后存活获胜
--
zgfunc[sgs.Damaged].qshs=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	local damage=data:toDamage()
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
	local owner = room:getOwner()
	for _,ap in sgs.qlist(room:getPlayers()) do
		local gname = ap:getGeneralName()
		local role1=owner:getRole()
		local role2=ap:getRole()
		if role1=="lord" then role1="loyalist" end
		if role2=="lord" then role2="loyalist" end
		if room:getMode() == "06_3v3" then
			if role1=="renegade" then role1="rebel" end
			if role2=="renegade" then role2="rebel" end
		end
		local diffgroup =false
		if role1~=role2 then diffgroup=true end
		if role1=="renegade" or role2=="renegade" then diffgroup=true end
		if not diffgroup then
			if gname=="liubei" or gname=="bgm_liubei" then
				has_liubei=true
				if owner:objectName()==ap:objectName() then issjy=true end
			elseif gname=="guanyu" or gname=="shenguanyu" or gname=="sp_guanyu" or gname=="neo_guanyu" then
				has_guanyu=true
				if owner:objectName()==ap:objectName() then issjy=true end
			elseif gname=="zhangfei" or gname=="neo_zhangfei" or gname=="bgm_zhangfei" then
				has_zhangfei=true
				if owner:objectName()==ap:objectName() then issjy=true end
			end
		end
	end
	if has_liubei and has_zhangfei and has_zhangfei and issjy then
		addZhanGong(room, name)
	end
end



-- wsww :: 为时未晚 :: 身为反贼，在一局游戏中杀死了除自己以外所有反贼并获得游戏的胜利
--
zgfunc[sgs.Death].wsww=function(self, room, event, player, data,isowner,name)
	local damage = data:toDamageStar()
	if not damage then return false end
	if getGameData("hegemony")==1 then return false end
	if room:getOwner():getRole()=="rebel" and damage.from and damage.from:objectName()==room:getOwner():objectName() 
		and damage.to:getRole()=="rebel" then
		addGameData(name,1)
	end	
end


-- wsww :: 为时未晚 :: 身为反贼，在一局游戏中杀死了除自己以外所有反贼并获得游戏的胜利
--
zgfunc[sgs.GameOverJudge].callback.wsww=function(room,player,data,name,result)
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
zgfunc[sgs.CardResponsed].xcdz=function(self, room, event, player, data,isowner,name)
	if data:toResponsed().m_card:isKindOf("Jink") and isowner then
		addGameData(name,1)
		if getGameData(name)==20 then addZhanGong(room,name) end
	end
end


-- xhjs :: 悬壶济世 :: 在一局游戏中，使用桃或技能累计将我方队友脱离濒死状态4次以上
--
function isSameGroup(a,b)
	local role1=a:getRole()
	local role2=b:getRole()
	if role1=="lord" then role1="loyalist" end
	if role2=="lord" then role2="loyalist" end
	if a:getRoom():getMode() == "06_3v3" then
		if role1=="renegade" then role1="rebel" end
		if role2=="renegade" then role2="rebel" end
	end
	return role1==role2 and role1~="renegade"
end

zgfunc[sgs.HpRecover].xhjs=function(self, room, event, player, data,isowner,name)
	local recover = data:toRecover()
	if player:getHp()<=0 and recover.recover+player:getHp()>=1 and recover.who
			and recover.who:objectName()==room:getOwner():objectName() and isSameGroup(player,recover.who) then
		addGameData(name,1)
		if getGameData(name)==4 then addZhanGong(room,name) end
	end
end




-- xnhx :: 邪念惑心 :: 作为忠臣在一局游戏中，在场上没有反贼时手刃主公
--
zgfunc[sgs.GameOverJudge].callback.xnhx=function(room,player,data,name,result)
	local damage = data:toDamageStar()
	if not damage then return false end
	if getGameData("hegemony")==1 then return false end
	for _,ap in sgs.qlist(room:getAlivePlayers()) do
		if ap:getRole()=="rebel" then return false end
	end
	if damage.from and damage.from:objectName()==room:getOwner():objectName() and damage.from:getRole()=="loyalist"
		and damage.to:getRole()=="lord" then
		addZhanGong(room,name)
	end
end


-- ymds :: 驭马大师 :: 在一局游戏中，至少更换过8匹马
--
zgfunc[sgs.CardsMoveOneTime].ymds=function(self, room, event, player, data,isowner,name)
	local move=data:toMoveOneTime()
	if move.from_places:contains(sgs.Player_PlaceEquip) and move.from:objectName()==room:getOwner():objectName()
		and move.reason==sgs.CardMoveReason_S_REASON_CHANGE_EQUIP then
		for _,cdid in sgs.qlist(move.card_ids) do
			if cdid:isKindOf("Horse") then
				addGameData(name,1)
				if getGameData(name)==8 then addZhanGong(room,name) end
			end
		end
	end
end


-- cqcz :: 此情常在 :: 在一局游戏中，布练师发动安恤4次并在阵亡情况下获胜
--
zgfunc[sgs.CardFinished].cqcz=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='bulianshi' then return false end
	if not isowner then return false end
	if data:toCardUse().card:isKindOf("AnxuCard") then 
		addGameData(name,1)
	end
end


-- cqcz :: 此情常在 :: 在一局游戏中，布练师发动安恤4次并在阵亡情况下获胜
--
zgfunc[sgs.GameOverJudge].callback.cqcz=function(room,player,data,name,result)
	if  room:getOwner():getGeneralName()~='bulianshi' then return false end
	if not isowner then return false end
	if result=='win' and getGameData(name)>=4 and room:getOwner():isDead() then
		addZhanGong(room,name)
	end
end


-- ctbc :: 拆桃不偿 :: 使用甘宁在一局游戏中发动“奇袭”从对方手牌中拆掉至少5张桃
--
zgfunc[sgs.CardsMoveOneTime].ctbc=function(self, room, event, player, data,isowner,name)
	if room:getOwner():getGeneralName()~="ganning" then return false end
	if room:getCurrent():objectName()~=room:getOwner():objectName() then return false end
	local move=data:toMoveOneTime()
	local from_places=sgs.QList2Table(move.from_places)
	local reason=move.reason
	if reason.m_playerId==room:getOwner():objectName() and reason.m_skillName=="qixi" and isowner then
		if table.contains(from_places,sgs.Player_PlaceHand) and move.to_place==sgs.Player_DiscardPile then
			local ids=sgs.QList2Table(move.card_ids)
			for _,cid in ipairs(ids) do
				local card=sgs.Sanguosha:getCard(cid)
				if card:isKindOf("Peach")  then
					addGameData(name,1)
					if getGameData(name)==5 then
						addZhanGong(room,name)
						return false
					end
				end
			end
		end
	end
end


-- dkjj :: 荡寇将军 :: 使用程普在一局游戏中，发动技能“疠火”杀死至少三名反贼最终获得胜利
--
zgfunc[sgs.Death].dkjj=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='chengpu' then return false end
	local damage=data:toDamageStar()
	if damage and damage.from and damage.from:objectName()==room:getOwner():objectName() and damage.card
		and damage.card:getSkillName()=="lihuo" and damage.to:getRole()=="rebel" then
		addGameData(name,1)
	end
end


-- dkjj :: 荡寇将军 :: 使用程普在一局游戏中，发动技能“疠火”杀死至少三名反贼最终获得胜利
--
zgfunc[sgs.GameOverJudge].callback.dkjj=function(room,player,data,name,result)
	if  room:getOwner():getGeneralName()~='chengpu' then return false end
	if result~='win' then return false end
	local damage=data:toDamageStar()
	if damage and damage.from and damage.from:objectName()==room:getOwner():objectName() and damage.card
		and damage.card:getSkillName()=="lihuo" and damage.to:getRole()=="rebel" then
		addGameData(name,1)
	end
	if getGameData(name)>=3 then addZhanGong(room,name) end
end




-- gzwb :: 固政为本 :: 使用张昭张纮在一局游戏中利用技能“固政”获得累计至少40张牌
--
zgfunc[sgs.CardsMoveOneTime].gzwb=function(self, room, event, player, data,isowner,name)
	if room:getOwner():getGeneralName()~='erzhang' or not isowner then return false end
	if room:getCurrent():getPhaseString()~="discard"
		or room:getCurrent():objectName()==room:getOwner():objectName() then return false end

	local move=data:toMoveOneTime()
	local reason=move.reason
	local from_places=sgs.QList2Table(move.from_places)

	if move.to_place~=sgs.Player_PlaceHand or move.to:objectName()~=room:getOwner():objectName() then return false end

	if table.contains(from_places,sgs.Player_DiscardPile) then
		local ids=sgs.QList2Table(move.card_ids)
		for _,cid in ipairs(ids) do
			addGameData(name,1)
			if getGameData(name)>=40 then
				addZhanGong(room,name)
				setGameData(name,-100)
				return false
			end
		end
	end
end


-- jfhz :: 解烦护主 :: 使用韩当在一局游戏游戏中发动“解烦”救过队友孙权至少两次
--
zgfunc[sgs.CardFinished].jfhz=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='handang' then return false end
	if not isowner then return false end
	local use=data:toCardUse()
	if use.to:getGeneralName()=="sunquan" and use.card:getSkillName()=="jiefan" then
		local role1=room:getOwner():getRole()
		local role2=ap:getRole()
		if role1=="lord" then role1="loyalist" end
		if role2=="lord" then role2="loyalist" end
		if room:getMode() == "06_3v3" then
			if role1=="renegade" then role1="rebel" end
			if role2=="renegade" then role2="rebel" end
		end
		local diffgroup =false
		if role1~=role2 then diffgroup=true end
		if role1=="renegade" or role2=="renegade" then diffgroup=true end
		if diffgroup then return false end
		addGameData(name,1)
		if getGameData(name)==2 then addZhanGong(room, name) end
	end
end


-- jjh :: 交际花 :: 使用孙尚香和全部其他角色皆使用过结姻
--
zgfunc[sgs.CardFinished].jjh=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='sunshangxiang' then return false end
	if not isowner then return false end
	local use=data:toCardUse()
	if use.card:isKindOf("JieyinCard") and use.to:first():getMark("jieyinzg_count")==0 then
		room:setPlayerMark(use.to, "jieyinzg_count", 1)
		local jieyin_count=0
		for _,ap in sgs.qlist(room:getPlayers()) do
			if ap:objectName()~=player:objectName() then
				if ap:getMark("jieyinzg_count")>0 then
					jieyin_count=jieyin_count+1
				end
			end
		end
		if jieyin_count==room:getPlayers():length()-1 then addZhanGong(room,name) end
	end
end


-- jjnh :: 禁军难护 :: 使用韩当在一局游戏中有角色濒死时发动“解烦”并出杀后均被闪避至少5次
--
zgfunc[sgs.SlashMissed].jjnh=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='handang' then return false end
	if not isowner then return false end
	local effect=data:toSlashEffect()
	if effect.slash:hasFlag("jiefan-slash") then
		addGameData(name,1)
		if getGameData(name)==5 then addZhanGong(room,name) end
	end
end


-- jwrs :: 军威如山 :: 使用☆SP甘宁在一局游戏中发动军威累计得到过至少6张“闪”
--
zgfunc[sgs.ChoiceMade].jwrs=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~="bgm_ganning" then return false end
	if not isowner then return false end
	local choices= data:toString():split(":")
	if choices[1]=="playerChosen"  and  choices[2]=="junweigive" then
		addGameData(name,1)
		if getGameData(name)==6 then addZhanGong(room,name) end
	end
end



-- jyh :: 解语花 :: 使用步练师在一局游戏中发动安恤摸八张牌以上
--
zgfunc[sgs.CardsMoveOneTime].jyh=function(self, room, event, player, data,isowner,name)
	if room:getOwner():getGeneralName()~="bulianshi" then return false end
	if room:getCurrent():getPhaseString()~="play"  then return false end

	local move=data:toMoveOneTime()
	local from_places=sgs.QList2Table(move.from_places)
	local reason=move.reason
	if reason.m_reason==sgs.CardMoveReason_S_REASON_GIVE and reason.m_playerId==room:getOwner():objectName()
			and isowner and room:getCurrent():objectName()==room:getOwner():objectName() then
		local ids=sgs.QList2Table(move.card_ids)
		for _,cid in ipairs(ids) do
			local card=sgs.Sanguosha:getCard(cid)
			if card:getSuit()~=sgs.Card_Spade  then
				addGameData(name,1)
				if getGameData(name)==8 then
					addZhanGong(room,name)
					return false
				end
			end
		end
	end
end




-- ssex :: 三思而行 :: 使用孙权在一局游戏中利用制衡获得至少4张无中生有以及4张桃
--
zgfunc[sgs.CardFinished].ssex=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='sunquan' then return false end
	if not isowner then return false end
	local x=player:getHandcardNum()
	local y=data:toCardUse().card:getSubcards():length()
	for i=0, y-1, 1 do
		if player:getHandcards():at(x-y+i):isKindOf("Peach") then
			addGameData(name.."_peach",1)
			if getGameData(name.."_peach")>=4 and getGameData(name.."_exnihilo")>=4 then 
				addZhanGong(room,name) 
				setGameData(name.."_peach", -100)
			end
		elseif player:getHandcards():at(x-y+i):isKindOf("ExNihilo") then
			addGameData(name.."_exnihilo",1)
			if getGameData(name.."_peach")>=4 and getGameData(name.."_exnihilo")>=4 then 
				addZhanGong(room,name) 
				setGameData(name.."_exnihilo", -100)
			end
		end
	end
end


-- sssl :: 深思熟虑 :: 使用孙权在一个回合内发动制衡的牌不少于10张
--
zgfunc[sgs.CardFinished].sssl=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='sunquan' then return false end
	if not isowner then return false end
	if data:toCardUse().card:getSubcards():length()>=10 then addZhanGong(room,name) end
end


-- syjh :: 岁月静好 :: 使用☆SP大乔在一局游戏中发动安娴五次并获胜
--
zgfunc[sgs.ChoiceMade].syjh=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~="bgm_daqiao" then return false end
	if not isowner then return false end
	local choices= data:toString():split(":")
	if choices[1]=="skillInvoke"  and  choices[2]=="anxian" and choices[3]=="yes" then
		addGameData(name,1)
	end
end

zgfunc[sgs.GameOverJudge].callback.syjh=function(room,player,data,name,result)
	if  room:getOwner():getGeneralName()~='bgm_daqiao' then return false end
	if result=='win' and getGameData(name)>=5 then
		addZhanGong(room,name)
	end
end


-- xxf :: 小旋风 :: 使用凌统在一局游戏中发动技能“旋风”弃掉其他角色累计15张牌
--
zgfunc[sgs.ChoiceMade].xxf=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~="lingtong" then return false end
	if not isowner then return false end
	local choices= data:toString():split(":")
	if choices[1]=="cardChosen" and choices[2]=="xuanfeng" then
		addGameData(name,1)
		if getGameData(name)==15 then
			addZhanGong(room,name)
		end
	end
end



-- ynnd :: 有难你当 :: 使用小乔在一局游戏中发动“天香”导致一名其他角色死亡
--
zgfunc[sgs.Death].ynnd=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='xiaoqiao' then return false end
	local damage=data:toDamageStar()
	if damage and damage.to:hasFlag("TianxiangTarget") then
		addZhanGong(room,name)
	end
end


zgfunc[sgs.GameOverJudge].callback.ynnd=function(room,player,data,name,result)
	if  room:getOwner():getGeneralName()~='xiaoqiao' then return false end
	local damage=data:toDamageStar()
	if damage and damage.to:hasFlag("TianxiangTarget") then
		addZhanGong(room,name)
	end
end


-- dkzz :: 杜康之子 :: 使用曹植在一局游戏中发动酒诗后成功用杀造成伤害累计5次
--
zgfunc[sgs.CardFinished].dkzz=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='caozhi' then return false end
	if not isowner then return false end
	local use=data:toCardUse()
	if use.card:getSkillName()=="jiushi" and player:getPhase()==sgs.Player_Play then 
		addTurnData(name.."_analeptic",1) 
	end
	if use.card:isKindOf("Slash") and player:getPhase()==sgs.Player_Play and getTurnData(name.."_slash")>0 then
		setTurnData(name.."_slash",0)
	end
end


zgfunc[sgs.SlashEffect].dkzz=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='caozhi' then return false end
	if not isowner then return false end
	local effect=data:toSlashEffect()
	if player:getPhase()==sgs.Player_Play and effect.drank and getTurnData(name.."_analeptic")==1 then
		addTurnData(name.."_slash",1)
	end
end


zgfunc[sgs.Damage].dkzz=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='caozhi' then return false end
	if not isowner then return false end
	local damage=data:toDamage()
	if damage.card and damage.card:isKindOf("Slash") and getTurnData(name.."_slash")>0 then
		setTurnData(name.."_slash",0)
		addGameData(name,1)
		if getGameData(name)==5 then addZhanGong(room,name) end
	end
end


-- dqzw :: 大权在握 :: 使用钟会在一局游戏中有超过8张权
--
zgfunc[sgs.DamageComplete].dqzw=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='zhonghui' then return false end
	if not isowner then return false end
	if player:getPile("power"):length()>=8 and getGameData(name)==0 then
		addGameData(name,1)
		addZhanGong(room,name)
	end
end


-- dym :: 大姨妈 :: 使用甄姬连续5回合洛神的第一次结果都是红色，不包括改判
--
zgfunc[sgs.EventPhaseEnd].dym=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='zhenji' then return false end
	if not isowner then return false end
	if player:getPhase()==sgs.Player_Start and getTurnData(name)==0 then setGameData(name, 0) end
end


-- dym :: 大姨妈 :: 使用甄姬连续5回合洛神的第一次结果都是红色，不包括改判
--
zgfunc[sgs.FinishRetrial].dym=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='zhenji' then return false end
	if not isowner then return false end
	local judge=data:toJudge()
	if judge.reason=="luoshen" and judge.who:objectName()==room:getOwner():objectName() then
		if judge:isGood() then 
			setGameData(name,0)
		else
			if room:getTag("retrial"):toBool()==false then
				addTurnData(name,1)
				addGameData(name,1)
				if getGameData(name)==5 then
					addZhanGong(room,name)
				end
			end
		end
	end
end


-- fynd :: 愤勇难当 :: 使用☆SP夏侯惇在一局游戏中，至少发动四次奋勇
--
zgfunc[sgs.ChoiceMade].fynd=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~="bgm_xiahoudun" then return false end
	if not isowner then return false end
	local choices= data:toString():split(":")
	if choices[1]=="skillInvoke"  and  choices[2]=="fenyong" and choices[3]=="yes" then
		addGameData(name,1)
		if getGameData(name)==4 then
			addZhanGong(room,name)
		end
	end
end


-- glnc :: 刚烈难存 :: 使用夏侯惇在一局游戏中连续4次刚烈判定均为红桃
--
zgfunc[sgs.FinishRetrial].glnc=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='xiahoudun' then return false end
	if not isowner then return false end
	local judge = data:toJudge()
	if judge.reason=="ganglie" and judge.who:objectName()==room:getOwner():objectName() then
		if judge:isGood() then
			setGameData(name,0)
		else
			addGameData(name,1)
			if getGameData(name)==4 then addZhanGong(room,name) end
		end
	end
end


-- jcyd :: 将驰有度 :: 使用曹彰发动将驰的两种效果各连续两回合
--
zgfunc[sgs.ChoiceMade].jcyd=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~="caozhang" then return false end
	if not isowner then return false end
	local choices= data:toString():split(":")
	for index, option in ipairs({"jiang","chi"}) do
		if choices[1]=="skillChoice"  and  choices[2]=="jiangchi" and choices[3]==option then
			setGameData(name..'_'..option,string.format("%s%d,",getGameData(name..'_'..option,''),getGameData('turncount')))
			local arr=string.sub(getGameData(name..'_'..option),1,-2):split(",")
			if #arr>=2 then
				if arr[#arr]-arr[#arr-1]==1 then
					addGameData(name..'_'..index,1)
					if getGameData(name..'_1')>=1 and getGameData(name..'_2')>=1 then
						addZhanGong(room,name)
						setGameData(name..'_'..index,-100)
					end
				end
			end
		end
	end
end



-- jsbc :: 坚守不出 :: 使用曹仁在一局游戏中连续8回合发动据守
--
zgfunc[sgs.ChoiceMade].jsbc=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~="caoren" then return false end
	if not isowner then return false end
	local choices= data:toString():split(":")
	if choices[1]=="skillInvoke"  and  choices[2]=="jushou" and choices[3]=="yes" then
		setGameData(name,string.format("%s%d,",getGameData(name,''),getGameData('turncount')))
		local arr=string.sub(getGameData(name),1,-2):split(",")
		if #arr>=8 then
			for i=#arr,#arr-6,-1 do
				if arr[i]-arr[i-1]~=1 then return false end
			end
			addZhanGong(room,name)
			setGameData(name,'')
		end
	end
end




-- qbcs :: 七步成诗 :: 使用曹植在一局游戏中发动酒诗7次
--
zgfunc[sgs.CardFinished].qbcs=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='caozhi' then return false end
	if data:toCardUse().card:getSkillName()=="jiushi" then
		addGameData(name,1)
		if getGameData(name)==7 then addZhanGong(room,name) end
	end
end


-- qjbc :: 奇计百出 :: 使用荀攸在一局游戏中，发动“奇策”使用至少六种锦囊
--
zgfunc[sgs.CardFinished].qjbc=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='xunyou' then return false end
	if not isowner then return false end
	local use=data:toCardUse()
	if use.card:getSkillName()=="qice" and getGameData(name..'_'..use.card:objectName())==0 then
		addGameData(name,1)
		addGameData(name..'_'..use.card:objectName(),1)
		if getGameData(name)==6 then addZhanGong(room,name) end
	end
end


-- qmjj :: 奇谋九计 :: 使用王异在一局游戏中至少成功发动九次秘计并获胜。
--
zgfunc[sgs.FinishRetrial].qmjj=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='wangyi' then return false end
	if not isowner then return false end
	local judge=data:toJudge()
	if judge.reason=="miji" and judge:isGood() and judge.who:objectName()==room:getOwner():objectName() then
		addGameData(name,1)
		if getGameData(name)==9 then addZhanGong(room,name) end
	end
end


-- qqtx :: 权倾天下 :: 使用钟会在一局游戏中发动“排异”累计摸牌至少10张
--
zgfunc[sgs.CardFinished].qqtx=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='zhonghui' then return false end
	if not isowner then return false end
	if data:toCardUse().card:isKindOf("PaiyiCard") and use.to:first():objectName()==player:objectName() then
		addGameData(name,2)
		if getGameData(name)>=10 then
			addZhanGong(room,name)
			setGameData(name,-100)
		end
	end
end


-- tmnw :: 天命难违 :: 使用司马懿被自己挂的闪电劈死，不包括改判
--
zgfunc[sgs.CardFinished].tmnw=function(self, room, event, player, data,isowner,name)
	if not isowner or player:getGeneralName()~="simayi" then return false end
	local use=data:toCardUse()
	local card=use.card
	if card:isKindOf('Lightning') then
		room:setCardFlag(card, name)
	end
end

zgfunc[sgs.CardsMoveOneTime].tmnw=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='simayi' then return false end
	local move=data:toMoveOneTime()
	local ids=sgs.QList2Table(move.card_ids)
	local card=sgs.Sanguosha:getCard(ids[1])

	local from_places=sgs.QList2Table(move.from_places)
	if table.contains(from_places,sgs.Player_PlaceDelayedTrick) and move.to_place~=sgs.Player_PlaceDelayedTrick then
		if card:hasFlag(name) then
			room:setCardFlag(card, '-'..name)
			room:getOwner():speak("天命难违:clear card flag")
		end
	end
end

zgfunc[sgs.FinishRetrial].tmnw=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='simayi' then return false end
	local judge=data:toJudge()
	if judge.reason=="lightning" and room:getTag("retrial"):toBool()==false 
			and judge.who:objectName()==room:getOwner():objectName() then
		setTurnData(name,1)
	else
		setTurnData(name,0)
	end
end

zgfunc[sgs.Death].tmnw=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='simayi' then return false end
	local damage = data:toDamageStar()
	if damage and damage.card and damage.card:isKindOf("Lightning") and damage.card:hasFlag(name)
			and player:objectName()==room:getOwner():objectName() then
		if getTurnData(name,0)==1 then
			addZhanGong(room,name)
		end
	end
end

zgfunc[sgs.GameOverJudge].callback.tmnw=function(room,player,data,name,result)
	if  room:getOwner():getGeneralName()~='simayi' then return false end
	local damage = data:toDamageStar()
	if damage and damage.card and damage.card:isKindOf("Lightning") and damage.card:hasFlag(name)
			and player:objectName()==room:getOwner():objectName() then
		if getTurnData(name,0)==1 then
			addZhanGong(room,name)
		end
	end
end


-- tmzf :: 天命之罚 :: 在一局游戏中，使用司马懿更改闪电判定牌至少劈中其他角色两次
--
zgfunc[sgs.FinishRetrial].tmzf=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='simayi' then return false end
	local judge=data:toJudge()
	if judge.reason=="lightning" and room:getTag("retrial"):toBool()==true
			and judge.who:objectName()~=room:getOwner():objectName() and judge:isBad() then
		local card= judge.card
		local simayi=room:getCardOwner(card:getId())
		player:speak(simayi:getGeneralName())
		if simayi and simayi:objectName()==room:getOwner():objectName() then
			addGameData(name,1)
			if getGameData(name)==2 then
				addZhanGong(room,name)
			end
		end
	end
end


-- wzxj :: 稳重行军 :: 使用于禁在一局游戏中发动“毅重”抵御至少4次黑色杀
--
zgfunc[sgs.SlashEffected].wzxj=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='yujin' then return false end
	local effect= data:toSlashEffect()
	if effect.to:hasSkill("yizhong") and effect.to:objectName()==room:getOwner():objectName() and effect.slash:isBlack() 
		and effect.to:getArmor()==nil then
		addGameData(name,1)
		if getGameData(name)==3 then
			addZhanGong(room,name)
		end
	end
end


-- xhdc :: 雪痕敌耻 :: 使用☆SP夏侯惇在一局游戏中，发动雪痕杀死一名角色
--
zgfunc[sgs.Death].xhdc=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='bgm_xiahoudun' then return false end
	local damage=data:toDamageStar()
	if damage and damage.from and damage.card and damage.card:getSkillName()=="xuehen" 
		and damage.from:objectName()==room:getOwner():objectName() then
		addZhanGong(room,name)
	end
end


-- xhdc :: 雪恨敌耻 :: 使用☆SP夏侯惇在一局游戏中，发动雪恨杀死一名角色
--
zgfunc[sgs.GameOverJudge].callback.xhdc=function(room,player,data,name,result)
	if  room:getOwner():getGeneralName()~='bgm_xiahoudun' then return false end
	local damage=data:toDamageStar()
	if damage and damage.from and damage.card and damage.card:getSkillName()=="xuehen" 
		and damage.from:objectName()==room:getOwner():objectName() then
		addZhanGong(room,name)
	end
end


-- xzxm :: 先知续命 :: 使用郭嘉在一局游戏中利用技能“天妒”收进至少4个桃
--
zgfunc[sgs.FinishRetrial].xzxm=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='guojia' then return false end
	local judge=data:toJudge()
	if player:hasSkill("tiandu") and judge.who:objectName()==room:getOwner():objectName() and judge.card:isKindOf("Peach") then
		addGameData(name,1)
		if getGameData(name)==4 then addZhanGong(room,name) end
	end
end


-- ybyt :: 义薄云天 :: 使用SP关羽在觉醒后杀死两个反贼并最后获胜
--
zgfunc[sgs.Death].ybyt=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='sp_guanyu' then return false end
	local damage=data:toDamageStar()
	if damage and damage.from and damage.from:objectName()==room:getOwner():objectName() 
		and damage.from:getMark("danji")>0 and damage.to:getRole()=="rebel" then
		addGameData(name,1)
	end
end


-- ybyt :: 义薄云天 :: 使用SP关羽在觉醒后杀死两个反贼并最后获胜
--
zgfunc[sgs.GameOverJudge].callback.ybyt=function(room,player,data,name,result)
	if  room:getOwner():getGeneralName()~='sp_guanyu' then return false end
	if result~='win' then return false end
	local damage=data:toDamageStar()
	if damage.from:objectName()==room:getOwner():objectName() and damage.from:getMark("danji")>0 and damage.to:getRole()=="rebel" then
		addGameData(name,1)
	end	
	if getGameData(name)>=2 then addZhanGong(room,name) end
end


-- ajnf :: 暗箭难防 :: 使用马岱在一局游戏中发动“潜袭”成功至少6次
--
zgfunc[sgs.FinishRetrial].ajnf=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='madai' then return false end
	local judge=data:toJudge()
	if judge.who:objectName()==room:getOwner():objectName() and judge.reason=="qianxi" and judge:isGood() then
		addGameData(name,1)
		if getGameData(name)==6 then addZhanGong(room,name) end
	end
end


-- cbhw :: 长坂虎威 :: 使用张飞在一回合内使用8张杀
--
zgfunc[sgs.CardFinished].cbhw=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='zhangfei' then return false end
	if player:objectName()~=room:getCurrent():objectName() then return false end
	local use=data:toCardUse()
	local card=use.card
	if card:isKindOf("Slash") then 
		addTurnData(name,1) 
		if getTurnData(name)==8 then
			addZhanGong(room,name)
		end
	end	
end


-- cbyx :: 长坂英雄 :: 使用赵云在一局游戏中，在刘禅为队友且存活情况下获胜
--
zgfunc[sgs.GameOverJudge].callback.cbyx=function(room,player,data,name,result)
	if  room:getOwner():getGeneralName()~='zhaoyun' then return false end
	if result~='win' then return false end
	for _,ap in sgs.qlist(room:getAlivePlayers()) do
		local role1=room:getOwner():getRole()
		local role2=ap:getRole()
		if role1=="lord" then role1="loyalist" end
		if role2=="lord" then role2="loyalist" end
		if room:getMode() == "06_3v3" then
			if role1=="renegade" then role1="rebel" end
			if role2=="renegade" then role2="rebel" end
		end
		local diffgroup =false
		if role1~=role2 then diffgroup=true end
		if role1=="renegade" or role2=="renegade" then diffgroup=true end
		if diffgroup==false and ap:getGeneralName()=="liushan" then
			addZhanGong(room,name)
		end
	end
end


-- dcxj :: 雕虫小技 :: 使用卧龙在一局游戏中发动“看破”至少15次
--
zgfunc[sgs.CardFinished].dcxj=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='wolong' then return false end
	local use=data:toCardUse()
	if use.card:isKindOf("Nullification") and use.card:getSkillName()=="kanpo" then
		addGameData(name,1)
		if getGameData(name)==15 then addZhanGong(room,name) end
	end
end


-- dyzh :: 当阳之吼 :: 在一局游戏中，使用☆SP张飞累计两次在大喝拼点成功的回合中用红“杀”手刃一名角色
--
zgfunc[sgs.Death].dyzh=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='bgm_zhangfei' then return false end
	local damage=data:toDamageStar()
	if damage and damage.from and damage.from:hasFlag("dahe") and damage.from==room:getOwner():objectName() 
		and damage.card:isKindOf("Slash") and damage.card:isRed() then
		addGameData(name,1)
		if getGameData(name)==2 then addZhanGong(room,name) end
	end
end


-- dyzh :: 当阳之吼 :: 在一局游戏中，使用☆SP张飞累计两次在大喝拼点成功的回合中用红“杀”手刃一名角色
--
zgfunc[sgs.GameOverJudge].callback.dyzh=function(room,player,data,name,result)
	if  room:getOwner():getGeneralName()~='bgm_zhangfei' then return false end
	local damage=data:toDamageStar()
	if damage.from:hasFlag("dahe") and damage.from==room:getOwner():objectName() and damage.card:isKindOf("Slash")
		and damage.card:isRed() then
		addGameData(name,1)
		if getGameData(name)==2 then addZhanGong(room,name) end
	end
end


-- gmzc :: 过目之才 :: 使用☆SP庞统一回合内累计拿到至少16张牌
--
zgfunc[sgs.CardsMoveOneTime].gmzc=function(self, room, event, player, data,isowner,name)
	local move=data:toMoveOneTime()
	if room:getOwner():getGeneralName()=="bgm_pangtong" and room:getOwner():getHandcardNum()>=16 and getGameData(name)==0 then
		addZhanGong(room,name)
		setGameData(name,1)
	end
end


-- hlzms :: 挥泪斩马谡 :: 使用诸葛亮杀死马谡
--
zgfunc[sgs.Death].hlzms=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='zhugeliang' then return false end
	local damage=data:toDamageStar()
	if damage and damage.from and damage.from:objectName()==room:getOwner():objectName() 
		and damage.to:getGeneralName()=="masu" then
		addZhanGong(room,name)
	end
end


-- hlzms :: 挥泪斩马谡 :: 使用诸葛亮杀死马谡
--
zgfunc[sgs.GameOverJudge].callback.hlzms=function(room,player,data,name,result)
	if  room:getOwner():getGeneralName()~='zhugeliang' then return false end
	local damage=data:toDamageStar()
	if damage and damage.from and damage.from:objectName()==room:getOwner():objectName() 
		and damage.to:getGeneralName()=="masu" then
		addZhanGong(room,name)
	end
end


-- hztx :: 虎子同心 :: 使用关兴张苞在父魂成功后，一个回合杀死至少三名反贼
--
zgfunc[sgs.Death].hztx=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='guanxingzhangbao' then return false end
	local damage=data:toDamageStar()
	if damage and damage.from and damage.from:objectName()==room:getOwner():objectName() 
		and damage.from:hasFlag("fuhun") and damage.to:getRole()=="rebel" then
		addTurnData(name,1)
		if getTurnData(name)==3 then addZhanGong(room,name) end
	end
end


-- hztx :: 虎子同心 :: 使用关兴张苞在父魂成功后，一个回合杀死至少三名反贼
--
zgfunc[sgs.GameOverJudge].callback.hztx=function(room,player,data,name,result)
	if  room:getOwner():getGeneralName()~='guanxingzhangbao' then return false end
	local damage=data:toDamageStar()
	if damage and damage.from and damage.from:objectName()==room:getOwner():objectName() 
		and damage.from:hasFlag("fuhun") and damage.to:getRole()=="rebel" then
		addTurnData(name,1)
		if getTurnData(name)==3 then addZhanGong(room,name) end
	end
end


-- rxbz :: 仁心布众 :: 使用刘备在一局游戏中，累计仁德至少30张牌
--
zgfunc[sgs.CardFinished].rxbz=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='liubei' then return false end
	if not isowner then return false end
	local use=data:toCardUse()
	if use.from:objectName()==room:getOwner():objectName() and use.card:isKindOf("RendeCard") then
		for i=1, use.card:getSubcards():length(), 1 do
			addGameData(name,1)
			if getGameData(name)==30 then addZhanGong(room,name) end
		end
	end
end


-- wxwd :: 惟贤惟德 :: 使用刘备在一个回合内发动仁德给的牌不少于10张
--
zgfunc[sgs.CardFinished].wxwd=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='liubei' then return false end
	if not isowner then return false end
	local use=data:toCardUse()
	if use.from:objectName()==room:getOwner():objectName() and use.card:isKindOf("RendeCard") then
		for i=1, use.card:getSubcards():length(), 1 do
			addTurnData(name,1)
			if getTurnData(name)==10 then addZhanGong(room,name) end
		end
	end
end


-- wyyd :: 无言以对 :: 使用徐庶在一局游戏中发动“无言”躲过南蛮入侵或万箭齐发累计4次
--
zgfunc[sgs.CardEffected].wyyd=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='xushu' then return false end
	if not isowner then return false end
	local effect=data:toCardEffect()
	if effect.to:hasSkill("wuyan") and (effect.card:isKindOf("SavageAssault") or effect.card:isKindOf("ArcheryAttack")) then
		addGameData(name,1)
		if getGameData(name)==4 then addZhanGong(room,name) end
	end
end


-- xlwzy :: 星落五丈原 :: 使用诸葛亮，在司马懿为敌方时阵亡
--
zgfunc[sgs.Death].xlwzy=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='zhugeliang' then return false end
	if not isowner then return false end
	for _,ap in sgs.qlist(room:getPlayers()) do
		local role1=room:getOwner():getRole()
		local role2=ap:getRole()
		if role1=="lord" then role1="loyalist" end
		if role2=="lord" then role2="loyalist" end
		if room:getMode() == "06_3v3" then
			if role1=="renegade" then role1="rebel" end
			if role2=="renegade" then role2="rebel" end
		end
		local diffgroup =false
		if role1~=role2 then diffgroup=true end
		if role1=="renegade" or role2=="renegade" then diffgroup=true end
		if diffgroup==true and (ap:getGeneralName()=="simayi" or ap:getGeneralName()=="shensimayi") then
			addZhanGong(room,name)
		end
	end
end


zgfunc[sgs.GameOverJudge].callback.xlwzy=function(room,player,data,name,result)
	if  room:getOwner():getGeneralName()~='zhugeliang' then return false end
	if player:objectName()~=room:getOwner():objectName() then return false end
	for _,ap in sgs.qlist(room:getPlayers()) do
		local role1=room:getOwner():getRole()
		local role2=ap:getRole()
		if role1=="lord" then role1="loyalist" end
		if role2=="lord" then role2="loyalist" end
		if room:getMode() == "06_3v3" then
			if role1=="renegade" then role1="rebel" end
			if role2=="renegade" then role2="rebel" end
		end
		local diffgroup =false
		if role1~=role2 then diffgroup=true end
		if role1=="renegade" or role2=="renegade" then diffgroup=true end
		if diffgroup==true and (ap:getGeneralName()=="simayi" or ap:getGeneralName()=="shensimayi") then
			addZhanGong(room,name)
		end
	end
end


-- ysadj :: 以死安大局 :: 使用马谡在一局游戏中发动“挥泪”使一名角色弃置8张牌
--
zgfunc[sgs.Death].ysadj=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='masu' then return false end
	if not isowner then return false end
	local damage=data:toDamageStar()
	if not (damage and damage.from) then return false end
	if not player:hasSkill('huilei') then return false end
	local num=damage.from:getHandcardNum()
	for i=0,3,1 do
		if damage.from:getEquip(i) then num = num + 1 end
	end
	if num>=8 then
		addZhanGong(room,name)
	end
end

zgfunc[sgs.GameOverJudge].callback.ysadj=function(room,player,data,name,result)
	if  room:getOwner():getGeneralName()~='masu' then return false end
	if not isowner then return false end
	local damage=data:toDamageStar()
	if not (damage and damage.from) then return false end
	if not player:hasSkill('huilei') then return false end
	local num=damage.from:getHandcardNum()
	for i=0,3,1 do
		if damage.from:getEquip(i) then num = num + 1 end
	end
	if num>=8 then
		addZhanGong(room,name)
	end
end


-- zlzn :: 昭烈之怒 :: 在一局游戏中，使用☆SP刘备发动昭烈杀死至少2人
--
zgfunc[sgs.Death].zlzn=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~="bgm_liubei" then return false end
	local damage=data:toDamageStar()
	if damage and damage.from and damage.from:objectName()==room:getOwner():objectName()
		and damage.from:getGeneralName()=="bgm_liubei" and  not damage.card then
		addGameData(name,1)
		if getGameData(name)==2 then
			addZhanGong(room,name)
		end
	end
end

zgfunc[sgs.GameOverJudge].callback.zlzn=function(room,player,data,name,result)
	if  room:getOwner():getGeneralName()~="bgm_liubei" then return false end
	local damage=data:toDamageStar()
	if damage and damage.from and damage.from:objectName()==room:getOwner():objectName()
		and damage.from:getGeneralName()=="bgm_liubei" and  not damage.card then
		addGameData(name,1)
		if getGameData(name)==2 then
			addZhanGong(room,name)
		end
	end
end


-- zmjzg :: 走马见诸葛 :: 使用旧徐庶在一局游戏中至少有3次举荐诸葛且用于举荐的牌里必须有马
--
zgfunc[sgs.CardFinished].zmjzg=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='nosxushu' then return false end
	if not isowner then return false end
	local use=data:toCardUse()
	if use.from:objectName()==room:getOwner():objectName() and use.card:isKindOf("NosJujianCard")
		and (use.to:getGeneralName()=="zhugeliang" or use.to:getGeneralName()=="wolong" or use.to:getGeneralName()=="shenzhugeliang") then
		local has_horse=false
		for _,cd in sgs.qlist(use.card:getSubcards()) do
			if sgs.Sanguosha:getCard(cd):isKindOf("Horse") then
				has_horse=true
			end
		end
		if has_horse then
			addGameData(name,1)
			if getGameData(name)==3 then addZhanGong(room,name) end
		end
	end
end


-- zzhs :: 智之化身 :: 使用黄月英在一局游戏发动20次集智至少20次
--
zgfunc[sgs.CardFinished].zzhs=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	if room:getOwner():getGeneralName()~='huangyueying' then return false end
	local use=data:toCardUse()
	local card=use.card
	if card:isNDTrick() then
		addGameData(name,1)
		if getGameData(name)==20 then
			addZhanGong(room,name)
		end
	end
end


-- bnzw :: 暴虐之王 :: 使用董卓在一局游戏中利用技能“暴虐”至少回血10次
--
zgfunc[sgs.HpRecover].bnzw=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='dongzhuo' then return false end
	if not isowner then return false end
	local recover=data:toRecover()
	if player:hasFlag("baonueused") then
		addGameData(name,1)
		if getGameData(name)==10 then addZhanGong(room,name) end
	end
end


-- hjqy :: 黄巾起义 :: 使用张角在一局游戏中收到过群雄角色给的闪至少3张，并至少三次雷击成功
--
zgfunc[sgs.CardEffected].hjqy=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	if player:getGeneralName()~="zhangjiao" then return false end
	local effect=data:toCardEffect()
	if effect.card:isKindOf("HuangtianCard") and sgs.Sanguosha:getCard(effect.card:getSubcards():first()):isKindOf("Jink") then
		setGameData(name..'_jink',math.min(3,getGameData(name..'_jink')+1))
		if getGameData(name..'_jink')==3 and getGameData(name..'_leiji')==3 then
			addZhanGong(room,name)
			setGameData(name..'_jink',-100)
		end
	end
end

zgfunc[sgs.FinishRetrial].hjqy=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='zhangjiao' then return false end
	local judge=data:toJudge()
	if judge.reason=="leiji" and judge:isBad() then
		setGameData(name..'_leiji',math.min(3,getGameData(name..'_leiji')+1))
		if getGameData(name..'_jink')==3 and getGameData(name..'_leiji')==3 then
			addZhanGong(room,name)
			setGameData(name..'_jink',-100)
		end
	end
end




-- jjyb :: 戒酒以备 :: 使用高顺在一局游戏中使用技能“禁酒”将至少3张酒当成杀使用或打出
--
zgfunc[sgs.CardFinished].jjyb=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	if player:getGeneralName()~="gaoshun" then return false end
	local use=data:toCardUse()
	local card=use.card
	if card:isKindOf("Slash") and sgs.Sanguosha:getCard(card:getSubcards():first()):isKindOf("Analeptic") 
		and card:getSkillName()=="jinjiu" then
		if getGameData(name)==3 then addZhanGong(room,name) end
	end
end



-- qldy :: 枪林弹雨 :: 使用袁绍在一回合内发动8次乱击
--
zgfunc[sgs.CardFinished].qldy=function(self, room, event, player, data,isowner,name)
	if not isowner or player:getGeneralName()~="yuanshao" then return false end
	local use=data:toCardUse()
	local card=use.card
	if card:getSkillName()=="luanji" then
		addTurnData(name,1)
		if getTurnData(name)==8 then
			addZhanGong(room,name)
		end
	end
end


-- sbfs :: 生不逢时 :: 使用双雄对关羽使用决斗，并因这个决斗被关羽杀死
--
zgfunc[sgs.Death].sbfs=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='yanliangwenchou' then return false end
	if not isowner then return false end
	local damage=data:toDamageStar()
	if not (damage and damage.from) then return false end
	local dname=damage.from:getGeneralName()
	if (dname=="guanyu" or dname=="sp_guanyu" or dname=="shenguanyu" or dname=="neo_guanyu") 
		and damage.card:isKindOf("Duel") then
		addZhanGong(room,name)
	end
end


zgfunc[sgs.GameOverJudge].callback.sbfs=function(room,player,data,name,result)
	if  room:getOwner():getGeneralName()~='yanliangwenchou' then return false end
	local damage=data:toDamageStar()
	if not (damage and damage.from) then return false end
	local dname=damage.from:getGeneralName()
	if (dname=="guanyu" or dname=="sp_guanyu" or dname=="shenguanyu" or dname=="neo_guanyu") 
		and damage.card:isKindOf("Duel") then
		addZhanGong(room,name)
	end
end


-- syqd :: 恃勇轻敌 :: 使用华雄在一局游戏中，在没有马岱在场的情况下由于体力上限减至0而死亡
--
zgfunc[sgs.Death].syqd=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~="huaxiong" then return false end
	if isowner and player:getMaxHp()<1 and room:findPlayer('madai',true) then
		addZhanGong(room,name)
	end
end

zgfunc[sgs.GameOverJudge].callback.syqd=function(room,player,data,name,result)
	if  room:getOwner():getGeneralName()~="huaxiong" then return false end
	if isowner and player:getMaxHp()<1 and room:findPlayer('madai',true) then
		addZhanGong(room,name)
	end
end


-- yzrx :: 医者仁心 :: 使用华佗在一局游戏中对4个身份的人都发动过青囊，游戏结束亮明身份后获得
--
zgfunc[sgs.CardFinished].yzrx=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	if  room:getOwner():getGeneralName()~='huatuo' then return false end
	local use=data:toCardUse()
	local card=use.card
	local tos=sgs.QList2Table(use.to)
	if card:getSkillName()~="qingnang" and card:isKindOf("Peach") and #tos>0 then
		local role=tos[1]:getRole()
		if not string.find(getGameData(name,''),role) then
			setGameData(name,getGameData(name)..role..",")
		end
	end
end

zgfunc[sgs.GameOverJudge].callback.yzrx=function(room,player,data,name,result)
	if  room:getOwner():getGeneralName()~='shensimayi' then return false end
	local arr=string.sub(getGameData(name,','),1,-2):split(",")
	if result=='win' and #arr==4 then
		addZhanGong(room,name)
	end
end

-- zsbsh :: 宗室遍四海 :: 使用刘表在一局游戏中利用技能“宗室”提高4手牌上限
--
zgfunc[sgs.EventPhaseEnd].zsbsh=function(self, room, event, player, data,isowner,name)
	if not isowner or player:getGeneralName()~="liubiao" then return false end
	local getKingdoms=function()
		local kingdoms={}
		local kingdom_number=0
		local players=room:getAlivePlayers()
		for _,aplayer in sgs.qlist(players) do
			if not kingdoms[aplayer:getKingdom()] then
				kingdoms[aplayer:getKingdom()]=true
				kingdom_number=kingdom_number+1
			end
		end
		return kingdom_number
	end
	if getGameData(name)==0 and player:getPhase()~=sgs.Player_Discard and player:getHandcardNum()-player:getHp()>=4 and getKingdoms()==4 then
		setGameData(name,1)
		addZhanGong(room,name)
	end
end


-- gqzl :: 顾曲周郎 :: 使用神周瑜连续至少4回合发动琴音回复体力
--
zgfunc[sgs.ChoiceMade].gqzl=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~="shenzhouyu" then return false end
	if not isowner then return false end
	local choices= data:toString():split(":")
	if choices[1]=="skillChoice"  and  choices[2]=="qinyin" and choices[3]=="up" then
		setGameData(name,string.format("%s%d,",getGameData(name,''),getGameData('turncount')))
		local arr=string.sub(getGameData(name),1,-2):split(",")
		if #arr>=4 then
			if arr[#arr]-arr[#arr-1]==1 and arr[#arr-1]-arr[#arr-2]==1 and arr[#arr-2]-arr[#arr-3]==1 then
				addZhanGong(room,name)
				setGameData(name,'')
			end
		end
	end
end



-- jjfs :: 绝境逢生 :: 使用神赵云在一局游戏中,当体力为一滴血的时候，一直保持一体力直到游戏获胜
--
zgfunc[sgs.HpRecover].jjfs=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='shenzhaoyun' then return false end
	if not isowner then return false end
	if player:getHp()==1 then
		addGameData(name,1)
	end
end

zgfunc[sgs.GameOverJudge].callback.jjfs=function(room,player,data,name,result)
	if  room:getOwner():getGeneralName()~='shenzhaoyun' then return false end
	if result=='win' and getGameData(name)==0 and room:getOwner():getHp()==1 then
		addZhanGong(room,name)
	end
end


-- lpkd :: 连破克敌 :: 使用神司马懿在一局游戏中发动3次连破并最后获胜
--
zgfunc[sgs.ChoiceMade].lpkd=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~="shensimayi" then return false end
	if not isowner then return false end
	local choices= data:toString():split(":")
	if choices[1]=="skillInvoke"  and  choices[2]=="lianpo" and choices[3]=="yes" then
		addGameData(name,1)
	end
end

zgfunc[sgs.GameOverJudge].callback.lpkd=function(room,player,data,name,result)
	if  room:getOwner():getGeneralName()~='shensimayi' then return false end
	if result=='win' and getGameData(name)>=3 then
		addZhanGong(room,name)
	end
end


-- sfgj :: 三分归晋 :: 使用神司马懿杀死刘备，孙权，曹操各累计10次
--
zgfunc[sgs.Death].sfgj=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~="shensimayi" then return false end
	local damage=data:toDamageStar()
	local victim=player:getGeneralName()
	if damage and damage.from and damage.from:objectName()==room:getOwner():objectName() and
			(victim=='liubei' or victim=='_sunquan' or victim=='_caocao') then
		addGlobalData(name..'_'..victim,1)
		if getGlobalData(name..'_liubei')>=10 and getGlobalData(name..'_sunquan')>=10 and getGlobalData(name..'_caocao')>=10 then
			addZhanGong(room,name)
			setGlobalData(name..'_liubei',-100)
			setGlobalData(name..'_sunquan',-100)
			setGlobalData(name..'_caocao',-100)
		end
	end
end

zgfunc[sgs.GameOverJudge].callback.sfgj=function(room,player,data,name,result)
	if  room:getOwner():getGeneralName()~="shensimayi" then return false end
	local damage=data:toDamageStar()
	local victim=player:getGeneralName()
	if damage and damage.from and damage.from:objectName()==room:getOwner():objectName() and
			(victim=='_liubei' or victim=='_sunquan' or victim=='_caocao') then
		addGlobalData(name..'_'..victim,1)
		if getGlobalData(name..'_liubei')>=10 and getGlobalData(name..'_sunquan')>=10 and getGlobalData(name..'_caocao')>=10 then
			addZhanGong(room,name)
			setGlobalData(name..'_liubei',-100)
			setGlobalData(name..'_sunquan',-100)
			setGlobalData(name..'_caocao',-100)
		end
	end
end

-- shgx :: 四海归心 :: 使用神曹操在一局游戏中受到2点伤害之后发动2次归心
--
zgfunc[sgs.ChoiceMade].shgx=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~="shencaocao" then return false end
	if not isowner then return false end
	local choices= data:toString():split(":")
	if choices[1]=="skillInvoke"  and  choices[2]=="guixin" and choices[3]=="yes" then
		addTurnData(name,1)
		if getTurnData(name)==2 and getTurnData(name.."_damage")==1 then
			addZhanGong(room,name)
		end
	end
end

zgfunc[sgs.Damaged].shgx=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	if  room:getOwner():getGeneralName()~="shencaocao" then return false end
	local damage = data:toDamage()
	if damage.damage==2 then
		setTurnData(name.."_damage",1)
	end
end


-- swzs :: 神威之势 :: 使用神赵云发动各花色龙魂各两次并在存活的情况下取得游戏胜利
--
zgfunc[sgs.CardFinished].swzs=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='shenzhaoyun' then return false end
	if not isowner then return false end
	local use=data:toCardUse()
	if use.card:getSkillName()=="longhun" then
		setGameData(name..'_'..use.card:getSuitString(), math.min(2,getGameData(name..'_'..use.card:getSuitString())+1 ) )
		if getGameData(name..'_spade')==2 and getGameData(name..'_heart')==2 and getGameData(name..'_club')==2
			and getGameData(name..'_diamond')==2 then
			addZhanGong(room,name)
			setGameData(name..'_heart',-100)
		end
	end
end

zgfunc[sgs.CardResponsed].swzs=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='shenzhaoyun' then return false end
	if not isowner then return false end
	local use=data:toResponsed()
	local card=use.m_card
	if card:getSkillName()=="longhun" then
		setGameData(name..'_'..card:getSuitString(), math.min(2,getGameData(name..'_'..card:getSuitString())+1 ) )
		if getGameData(name..'_spade')==2 and getGameData(name..'_heart')==2 and getGameData(name..'_club')==2
			and getGameData(name..'_diamond')==2 then
			addZhanGong(room,name)
			setGameData(name..'_heart',-100)
		end
	end
end


-- tyzm :: 桃园之梦 :: 使用神关羽在一局游戏中阵亡后发动武魂判定结果为桃园结义
--
zgfunc[sgs.FinishRetrial].tyzm=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='shenguanyu' then return false end
	local judge=data:toJudge()
	if judge.reason=="wuhun" and judge.card:isKindOf("GodSalvation") then
		addZhanGong(room,name)
	end
end


-- wmsz :: 无谋竖子 :: 使用神吕布在一局游戏中发动无谋至少8次
--
zgfunc[sgs.CardFinished].wmsz=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	if room:getOwner():getGeneralName()~='shenlvbu' then return false end
	local use=data:toCardUse()
	local card=use.card
	if card:isNDTrick() then
		addGameData(name,1)
		if getGameData(name)==8 then
			addZhanGong(room,name)
		end
	end
end


-- yrbf :: 隐忍不发 :: 使用神司马懿在一局游戏中发动忍戒至少10次并获胜
--
zgfunc[sgs.CardDiscarded].yrbf=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	if  room:getOwner():getGeneralName()~='shensimayi' then return false end
	if player:getPhase()~=sgs.Player_Discard then return false end
	local card = data:toCard()
	addGameData(name,card:subcardsLength())
end

zgfunc[sgs.Damaged].yrbf=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	if  room:getOwner():getGeneralName()~='shensimayi' then return false end
	local damage = data:toDamage()
	addGameData(name,damage.damage)
end

zgfunc[sgs.GameOverJudge].callback.yrbf=function(room,player,data,name,result)
	if  room:getOwner():getGeneralName()~='shensimayi' then return false end
	if result=='win' and getGameData(name)>=10 then
		addZhanGong(room,name)
	end
end

-- zszn :: 战神之怒 :: 使用神吕布在一局游戏中发动至少4次神愤、3次无前
--
zgfunc[sgs.CardFinished].zszn=function(self, room, event, player, data,isowner,name)
	if room:getOwner():getGeneralName()~="shenlvbu" then return false end
	if not isowner then return false end
	local use=data:toCardUse()
	local card=use.card
	if card:isKindOf("ShenfenCard") then
		setGameData(name..'_shenfen',math.min(4,getGameData(name..'_shenfen')+1))
		if getGameData(name..'_shenfen')==4 and getGameData(name..'_wuqian')==3 then
			addZhanGong(room,name)
			setGameData(name..'_shenfen',-100)
		end
	end
end

zgfunc[sgs.CardFinished].zszn=function(self, room, event, player, data,isowner,name)
	if room:getOwner():getGeneralName()~="shenlvbu" then return false end
	if not isowner then return false end
	local use=data:toCardUse()
	local card=use.card
	if card:isKindOf("WuqianCard") then
		setGameData(name..'_wuqian',math.min(3,getGameData(name..'_wuqian')+1))
		if getGameData(name..'_shenfen')==4 and getGameData(name..'_wuqian')==3 then
			addZhanGong(room,name)
			setGameData(name..'_shenfen',-100)
		end
	end
end


-- sxnj :: 神仙难救 :: 使用贾诩在你的回合中有至少3个角色阵亡
--
zgfunc[sgs.Death].sxnj=function(self, room, event, player, data,isowner,name)
	if room:getOwner():getGeneralName()~='jiaxu' then return false end
	if room:getCurrent():objectName()~=room:getOwner():objectName() then return false end
	addTurnData(name,1)
	if getTurnData(name)==3 then
		addZhanGong(room,name)
	end
end

zgfunc[sgs.GameOverJudge].callback.sxnj=function(room,player,data,name,result)
	if room:getOwner():getGeneralName()~='jiaxu' then return false end
	if room:getCurrent():objectName()~=room:getOwner():objectName() then return false end
	addTurnData(name,1)
	if getTurnData(name)==3 then
		addZhanGong(room,name)
	end
end


-- jzyf :: 见者有份 :: 使用杨修在一局游戏中发动技能“啖酪”至少6次
--
zgfunc[sgs.ChoiceMade].jzyf=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~="yangxiu" then return false end
	if not isowner then return false end
	local choices= data:toString():split(":")
	if choices[1]=="skillInvoke"  and  choices[2]=="danlao" and choices[3]=="yes" then
		addGameData(name,1)
		if getGameData(name)==6 then
			addZhanGong(room,name)
		end
	end
end

-- xhrb :: 心如寒冰 :: 使用张春华在一局游戏中至少触发“绝情”10次以上
--
zgfunc[sgs.Predamage].xhrb=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~="zhangchunhua" then return false end
	if not isowner then return false end
	addGameData(name,1)
	if getGameData(name)==10 then
		addZhanGong(room,name)
	end
end

-- lbss :: 乐不思蜀 :: 在对你的“乐不思蜀”生效后的回合弃牌阶段弃置超过8张手牌
--
zgfunc[sgs.FinishRetrial].lbss=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	local judge=data:toJudge()
	if judge.reason=="indulgence" and judge.who:objectName()==room:getOwner():objectName() and judge:isBad() then
		setTurnData(name,1)
	end
end

zgfunc[sgs.CardDiscarded].lbss=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	if player:getPhase()~=sgs.Player_Discard then return false end
	if getTurnData(name)~=1 then return false end
	local card = data:toCard()
	local count = 0
	for _,cdid in sgs.qlist(card:getSubcards()) do
		count=count +1
		if count==8 then addZhanGong(room,name) end
	end
end


-- ydqb :: 原地起爆 :: 回合开始阶段你1血0牌的情况下，一回合内杀死3名角色
--
zgfunc[sgs.EventPhaseStart].ydqb=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	if player:getPhase()==sgs.Player_Start and player:isKongcheng() and player:getHp()==1 then
		setTurnData(name..'_start',1)
	end
end

zgfunc[sgs.Death].ydqb=function(self, room, event, player, data,isowner,name)
	if room:getCurrent():objectName()~=room:getOwner():objectName() then return false end
	addTurnData(name,1)
	if getTurnData(name)==3 and getTurnData(name..'_start')==1 then
		addZhanGong(room,name)
	end
end

zgfunc[sgs.GameOverJudge].callback.ydqb=function(room,player,data,name,result)
	if room:getCurrent():objectName()~=room:getOwner():objectName() then return false end
	addTurnData(name,1)
	if getTurnData(name)==3 and getTurnData(name..'_start')==1 then
		addZhanGong(room,name)
	end
end

-- hyhs :: 红颜祸水 :: 使用SP貂蝉在一局游戏中，两次对主公和忠臣发动技能“离间”并导致2名忠臣阵亡
--
zgfunc[sgs.Death].hyhs=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~="sp_diaochan" then return false end
	local damage=data:toDamageStar()
	if not damage then return false end
	if  room:getCurrent():objectName()==room:getOwner():objectName() and damage.card and damage.card:getSkillName()=="lijian"
			and damage.from:isLord() and damage.to:getRole()=='loyalist' then
		addGameData(name,1)
		if getGameData(name)==2 then
			addZhanGong(room,name)
		end
	end
end

zgfunc[sgs.GameOverJudge].callback.hyhs=function(room,player,data,name,result)
	if  room:getOwner():getGeneralName()~="sp_diaochan" then return false end
	local damage=data:toDamageStar()
	if not damage then return false end
	if  room:getCurrent():objectName()==room:getOwner():objectName() and damage.card and damage.card:getSkillName()=="lijian"
			and damage.from:isLord() and damage.to:getRole()=='loyalist' then
		addGameData(name,1)
		if getGameData(name)==2 then
			addZhanGong(room,name)
		end
	end
end


-- wzsh :: 威震四海 :: 一次对其他角色造成至少5点伤害
--
zgfunc[sgs.Damage].wzsh=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	local damage=data:toDamage()
	if damage.damage>=5 and not damage.chain then
		addZhanGong(room,name)
	end
end

-- dsdnx :: 屌丝的逆袭 :: 身为虎牢关联军的先锋，第一回合就爆了虎牢布的菊花
--
zgfunc[sgs.HpChanged].dsdnx=function(self, room, event, player, data,isowner,name)
	if room:getMode()~="04_1v3" or not player:isLord() then return false end
	if room:getCurrent():objectName()~=room:getOwner():objectName() or getGameData("turncount")>1 then return false end
	if room:getOwner():getSeat()==2 and player:getHp()<= 4 and player:getMark("secondMode") == 0 then
		addZhanGong(room,name)
	end
end

-- kdzz :: 坑爹自重 :: 使用刘禅，孙权&孙策，曹丕&曹植坑了自己的老爹
--
zgfunc[sgs.Death].kdzz=function(self, room, event, player, data,isowner,name)
	local damage=data:toDamageStar()
	if damage and damage.from and damage.from:objectName()==room:getOwner():objectName() then
		local kengdie=false
		local from=damage.from:getGeneralName()
		local to=damage.to:getGeneralName()
		if string.match(to,'liubei') and from=='liushan' then kengdie=true end
		if string.match(to,'caocao') and (from=='caopi' or from=='caozhi') then kengdie=true end
		if string.match(to,'sunjian') and (from=='sunquan' or from=='sunce') then kengdie=true end
		if kengdie then
			addZhanGong(room,name)
		end
	end
end

zgfunc[sgs.GameOverJudge].callback.kdzz=function(room,player,data,name,result)
	local damage=data:toDamageStar()
	if damage and damage.from and damage.from:objectName()==room:getOwner():objectName() then
		local kengdie=false
		local from=damage.from:getGeneralName()
		local to=damage.to:getGeneralName()
		if string.match(to,'liubei') and from=='liushan' then kengdie=true end
		if string.match(to,'caocao') and (from=='caopi' or from=='caozhi') then kengdie=true end
		if string.match(to,'sunjian') and (from=='sunquan' or from=='sunce') then kengdie=true end
		if kengdie then
			addZhanGong(room,name)
		end
	end
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

	local trs=genTranslation()
	local name
	if string.find(key,'_')	then
		local arr=key:split("_")
		name=trs[arr[1]]..'_'..arr[2]
	else
		name=trs[key]
	end
	if name==nil then name=key end
	myroom:getOwner():speak(string.format("%s+%d=%d",name,val,zggamedata[key]))
end

function setGameData(key,val)	
	zggamedata[key]=val

	local trs=genTranslation()
	local name
	if string.find(key,'_')	then
		local arr=key:split("_")
		name=trs[arr[1]]..'_'..arr[2]
	else
		name=trs[key]
	end
	if name==nil then name=key end
	myroom:getOwner():speak(string.format("%s=%s",name,zggamedata[key]))

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

	local trs=genTranslation()
	local name
	if string.find(key,'_')	then
		local arr=key:split("_")
		name=trs[arr[1]]..'_'..arr[2]
	else
		name=trs[key]
	end
	if name==nil then name=key end
	myroom:getOwner():speak(string.format("%s+%d=%d",name,val,zgturndata[key]))
end

function setTurnData(key,val)
	zgturndata[key]=val

	local trs=genTranslation()
	local name
	if string.find(key,'_')	then
		local arr=key:split("_")
		name=trs[arr[1]]..'_'..arr[2]
	else
		name=trs[key]
	end
	if name==nil then name=key end
	myroom:getOwner():speak(string.format("%s=%s",name,zgturndata[key]))
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
			sgs.CardResponsed,sgs.TurnStart,sgs.HpRecover,sgs.DamageInflicted,sgs.ConfirmDamage,sgs.HpChanged,
			sgs.Damaged,sgs.FinishRetrial},
	priority = 6,
	can_trigger = function()
		return true
	end,

	on_trigger = function(self, event, player, data)
		local room = player:getRoom()
		local owner= room:getOwner():objectName()==player:objectName()

		myroom = room
		
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
	events = {sgs.CardFinished,sgs.EventPhaseStart,sgs.EventPhaseEnd,sgs.Pindian,sgs.CardEffect,sgs.CardEffected,sgs.Predamage,sgs.ChoiceMade,
		sgs.SlashEffected,sgs.SlashEffect,sgs.CardsMoveOneTime,sgs.CardDiscarded,sgs.CardResponsed,
		sgs.SlashMissed},
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
