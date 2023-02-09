//Script to manage deterioration
class Deteriorator extends SqRootScript
{
	static DETERIORATE_TIMER = 10; //How often the script updates to check items. You shouldn't touch this.
	static DETERIORATE_RATE = 600; //At what rate do items degrade (in seconds). After this many seconds, will lose 1 from stack.
	static MAX_REMOVE_EXTRA = 10; //If the item contains more than this many stacks, roll for Max Removals
	static MAX_REMOVALS = 4; //How many items can be taken from the stack at once
	static DISABLE_ELEVATOR = true;

	function GetItemTime(item)
	{
		return GetData(item + "_removed");
		//return (Property.Get(item,"CSProjectile")).tofloat();
	}
	
	function SetItemTime(item,time)
	{
		SetData(item + "_removed",time);
		//Property.SetSimple(item,"CSProjectile",time);
	}
	
	function GetItemStack(item)
	{
		return Property.Get(item,"StackCount");
	}

	function OnBeginScript()
	{
		if (!GetData("Started"))
		{
			print ("Deteriorator Added");
			SetOneShotTimer("DeteriorateTimer",DETERIORATE_TIMER);
			SetData("Started",1);
		}
		else
			DeteriorateItems();
	}

	function GetCurrentTimeSeconds()
	{
		return ShockGame.SimTime() * 0.001;
	}

	function OnObjectAdded()
	{
		local item = message().data;

		//ShockGame.AddText(item + " was added","Player");
		
		RemoveLinks(item);
	}
	
	function OnObjectRemoved()
	{
		local item = message().data;
		
		local isGoodies = isArchetype(item,-49) || isArchetype(item,-90);
		if (!isGoodies)
			return;
			
		if (DISABLE_ELEVATOR)
			Property.SetSimple(item,"ElevAble",false);
		
		//ShockGame.AddText(item + " was removed","Player");
		
		if (!Link.AnyExist(linkkind("Target"),self,item))
		{
			SetItemTime(item,GetCurrentTimeSeconds());
			Link.Create(linkkind("Target"),self,item);
		}
	}
	
	function DeteriorateItems()
	{
		//Don't degrade anything while we have a container open,
		//so that we don't lose any items inside the container
		local currentContainer = ShockGame.OverlayGetObj();
		if (currentContainer != 0)
			return;
	
		foreach (link in Link.GetAll(linkkind("Target"),self))
		{		
			local lObj = sLink(link).dest;
			Deteriorate(lObj);
		}
	}
	
	//Compares an items removal time with the current sim time
	//If it's due to be deteriorated, it removes some items from it's stacks
	function Deteriorate(item)
	{
		if (Link.AnyExist(linkkind("Contains"),"Player",item))
		{
			//ShockGame.AddText("Removing inventory item " + item, "Player");
			RemoveLinks(item);
			return;
		}
	
		local timeDiff = GetCurrentTimeSeconds() - GetItemTime(item);
		
		//ShockGame.AddText("Time diff for " + ShockGame.GetArchetypeName(item) + " (" + item + ") is " + (timeDiff),"Player");
		
		local numRemovals = floor(timeDiff / DETERIORATE_RATE);
		
		//ShockGame.AddText("numRemovals: " + numRemovals + " (timeDiff: " + timeDiff + ")","Player");
			
		if (numRemovals > 0)
		{
			if (GetItemStack(item) > MAX_REMOVE_EXTRA)
				numRemovals = Data.RandInt(numRemovals,numRemovals + MAX_REMOVALS - 1);
			
			ReduceStackSize(item,numRemovals);
			
			//Refresh removal timer
			SetItemTime(item,GetCurrentTimeSeconds());
		}
	}
	
	function OnTimer()
	{
		//ShockGame.AddText("tick","Player");
	
		DeteriorateItems();
	
		//Restart Counter
		SetOneShotTimer("DeteriorateTimer",DETERIORATE_TIMER);
	}
	
	function isArchetype(obj,type)
	{	
		return obj == type || Object.Archetype(obj) == type || Object.Archetype(obj) == Object.Archetype(type) || Object.InheritsFrom(obj,type);
	}
	
	function ReduceStackSize(item,amount)
	{
		local stackcount = GetItemStack(item);
		if (stackcount <= amount)
		{
			Object.Destroy(item);
			RemoveLinks(item);
		}
		else
			Property.SetSimple(item,"StackCount",stackcount - amount);
	}
	
	function RemoveLinks(item)
	{
		foreach (link in Link.GetAll(linkkind("Target"),self,item))
			Link.Destroy(link);
	}
}

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
			PostMessage(deteriator,"ObjectRemoved",item);
		}
		else
		{
			PostMessage(deteriator,"ObjectAdded",item);
		}
	}
}