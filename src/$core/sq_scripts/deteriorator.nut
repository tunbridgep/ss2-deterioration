//Player script to detect dropped items
class DeteriorateDroppedItems extends SqRootScript
{
	//Run Once
	function OnBeginScript()
	{	
		if (!GetData("Started"))
		{
			SetData("Started",1);
			local deteriator = Object.Create("Deteriorator");
			SetData("DeteriatorObj",deteriator);
		}
	}

	function OnContainer()
	{
		local deteriator = GetData("DeteriatorObj");
	
		if (!deteriator)
			return;
	
		local item = message().containee;
	
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
	static DETERIORATE_TIMER = 1; //How often the script updates to check itself. You shouldn't touch this.
	static DETERIORATE_RATE = 20; //At what rate do items degrade (in seconds). After this many seconds, will lose 1 from stack.
	static MAX_REMOVE_EXTRA = 12; //If the item contains more than this many stacks, roll for Max Removals
	static MAX_REMOVALS = 4; //How many items can be taken from the stack at once

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
		//Deteriorate();
		if (!InPlayerInventory())
		{
			StartTimer(0.05);
			//ShockGame.AddText("Timer For " + self + " is " + GetItemTime(),"Player");
		}
	}

	function OnRemovedFromInv()
	{
		SetItemTime(GetCurrentTimeSeconds());
		StartTimer();
	}
	
	function OnAddedToInv()
	{
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
	
	function Deteriorate()
	{
		if (InPlayerInventory())
		{
			//ShockGame.AddText("Ignoring inventory item " + self, "Player");
			return;
		}
			
		local timeDiff = GetCurrentTimeSeconds() - GetItemTime();
					
		local numRemovals = floor(timeDiff / DETERIORATE_RATE);
		
		//ShockGame.AddText("Deteriorating " + self + " (" + timeDiff + ")","Player");

		local exists = true;

		if (numRemovals > 0 && timeDiff > 0)
		{
			if (GetItemStack() > MAX_REMOVE_EXTRA)
				numRemovals = Data.RandInt(numRemovals,numRemovals + MAX_REMOVALS - 1);
			
			exists = ReduceStackSize(numRemovals);
			
			//Refresh removal timer
			SetItemTime(GetCurrentTimeSeconds());
		}
		
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