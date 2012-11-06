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
		gainSkill(room)
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
		sgs.CardEffected,sgs.SlashEffected,sgs.SlashEffect,sgs.CardsMoveOneTime,sgs.FinishRetrial},
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
