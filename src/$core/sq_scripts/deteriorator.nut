//Player script to detect dropped items
class DeteriorateDroppedItems extends SqRootScript
{
	function OnContainer()
	{
		local item = message().containee;
		
		if (!IsValidItem(item))
			return;
	
		if (message().event == eContainsEvent.kContainRemove)
		{
			if (!HasScript(item))
				DynamicScriptAdd(item);
			PostMessage(item,"RemovedFromInv");
			//PostMessage(deteriator,"ObjectRemoved",item);
		}
		else
		{
			PostMessage(item,"AddedToInv");
			//PostMessage(deteriator,"ObjectAdded",item);
		}
	}
	
	//Don't deteriorate weapons
	function IsValidItem(item)
	{
		//If it's not Goodies or Items, it's not valid
		if (!isArchetype(item,-49) && !isArchetype(item,-90))
			return false;
			
		//If it is Goodies, some items are still not valid
	
		if (isArchetype(item,-78) 	//Armour
		|| isArchetype(item,-218) 	//Researchable
		//|| isArchetype(item,-128) 	//Chemicals
		|| isArchetype(item,-1341) 	//Toxin-A
		|| isArchetype(item,-145) 	//Sb
		|| isArchetype(item,-139) 	//V
		|| isArchetype(item,-76) 	//Audio Logs
		|| isArchetype(item,-85) 	//Nanites
		|| isArchetype(item,-938) 	//Cyber Modules
		|| isArchetype(item,-500)) 	//PDA Soft
		{
			return false;
		}
		
		
		return true;
	}
	
	static function isArchetype(obj,type)
	{	
		return obj == type || Object.Archetype(obj) == type || Object.Archetype(obj) == Object.Archetype(type) || Object.InheritsFrom(obj,type);
	}
	
	//This is both the most amazing AND most disgusting thing I have ever made NewDark do
	//I'm really sorry...
	function DynamicScriptAdd(item)
	{
		local script1 = Property.Get(item,"Scripts","Script 0");
		local script2 = Property.Get(item,"Scripts","Script 1");
		local script3 = Property.Get(item,"Scripts","Script 2");
		local script4 = Property.Get(item,"Scripts","Script 3");
		
		if (script1 == "")
			Property.Set(item,"Scripts","Script 0","DeteriorateItem");
		else if (script2 == "")
			Property.Set(item,"Scripts","Script 1","DeteriorateItem");
		else if (script3 == "")
			Property.Set(item,"Scripts","Script 2","DeteriorateItem");
		else if (script4 == "")
			Property.Set(item,"Scripts","Script 3","DeteriorateItem");
		else
			print ("Deteriation Error: Object " + item + " (" + ShockGame.GetArchetypeName(item) + ") has no available script slots!");
	}
	
	function HasScript(item)
	{
		local script1 = Property.Get(item,"Scripts","Script 0");
		local script2 = Property.Get(item,"Scripts","Script 1");
		local script3 = Property.Get(item,"Scripts","Script 2");
		local script4 = Property.Get(item,"Scripts","Script 3");
		
		return script1 == "DeteriorateItem" || script2 == "DeteriorateItem" || script3 == "DeteriorateItem" || script4 == "DeteriorateItem";
	}
}

class DeteriorateItem extends SqRootScript
{
	skipDistanceCheck = null;

	static DETERIORATE_TIMER = 10; //How often the script updates to check itself. You shouldn't touch this.
	static DETERIORATE_RATE = 300; //At what rate do items degrade (in seconds). After this many seconds, will lose items from stack.
	static STACK_LOSS = 6; 			//How many items will be lost from the stack each removal
	static MAX_PLAYER_DIST = 60; //How far away the player must be from an item before it deteriorates

	function GetCurrentTimeSeconds()
	{
		return ShockGame.SimTime() * 0.001;
	}

	function GetItemTime()
	{
		//return GetData("_removed");
		return Property.Get(self,"DoorOpenSound").tofloat();
	}
	
	function SetItemTime(time)
	{
		//SetData("_removed",time);
		Property.SetSimple(self,"DoorOpenSound",time);
	}
	
	function GetItemStack()
	{
		return Property.Get(self,"StackCount");
	}

	function StartTimer(time = 0)
	{
		if (time <= 0)
			time = DETERIORATE_TIMER;
		
		StopTimer();
		local timer = SetOneShotTimer("DeteriorateTimer",time);
		SetData("_timer",timer);
		//ShockGame.AddText("Starting Timer For " + self,"Player");
	}
	
	function StopTimer()
	{
		local timer = GetData("_timer");
		if (timer)
		{
			KillTimer(timer);
			//ShockGame.AddText("Killing Timer For " + self,"Player");
		}
		
	}

	function OnBeginScript()
	{
		skipDistanceCheck = true; //We don't care about distance when moving between levels
		//Deteriorate();
		if (!InPlayerInventory())
		{
			StartTimer(0.05);
			//ShockGame.AddText("Timer For " + self + " is " + GetItemTime(),"Player");
		}
	}

	function OnRemovedFromInv()
	{
		skipDistanceCheck = false;
		SetItemTime(GetCurrentTimeSeconds());
		StartTimer();
	}
	
	function OnAddedToInv()
	{
		if (InPlayerInventory())
			StopTimer();
	}
	
	function OnTimer()
	{	
		Deteriorate();
	}
	
	function InPlayerInventory()
	{
		return Link.AnyExist(linkkind("Contains"),"Player",self);
	}
	
	function GetPlayerDistance()
	{
		local playerPos = Object.Position("Player");
		local pos = Object.Position(self);
		local vecdiff = playerPos - pos;
		return vecdiff.Length();
	}
	
	function Deteriorate()
	{
		if (InPlayerInventory())
		{
			//ShockGame.AddText("Ignoring inventory item " + self, "Player");
			return;
		}
			
		local timeDiff = GetCurrentTimeSeconds() - GetItemTime();
					
		local numRemovals = floor(timeDiff / DETERIORATE_RATE);
		numRemovals *= STACK_LOSS; // + Data.RandInt(0,1);
		
		//ShockGame.AddText("Deteriorating " + self + " (" + timeDiff + ")","Player");

		local exists = true;
		
		local playerDistance = GetPlayerDistance();
		
		//print ("playerDistance: " + playerDistance);

		if (numRemovals > 0 && timeDiff > 0 && (playerDistance >= MAX_PLAYER_DIST || skipDistanceCheck))
		//if (numRemovals > 0 && timeDiff > 0 && playerDistance >= MAX_PLAYER_DIST)
		{
			//print("Deteriorator: reducing stacks for " + self + " by " + numRemovals);
			exists = ReduceStackSize(numRemovals);
			
			//Refresh removal timer
			SetItemTime(GetCurrentTimeSeconds());
		}
		
		skipDistanceCheck = false;
		
		if (exists)
			StartTimer();
	}
	
	
	function ReduceStackSize(amount)
	{
		local stackcount = GetItemStack();
		if (stackcount <= amount)
		{
			Object.Destroy(self);
			return false;
		}
		else
		{
			Property.SetSimple(self,"StackCount",stackcount - amount);
			return true;
		}
	}
}