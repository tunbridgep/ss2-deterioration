//Script to manage deterioration
class Deteriorator extends SqRootScript
{
	static DETERIORATE_TIMER = 10; //How often to update deterioration, NOT the rate, just how often the script updates item status
	static DETERIORATE_RATE = 600; //At what rate do items degrade (in seconds). After this many seconds, will lose 1 from stack.

	function OnBeginScript()
	{
		if (!GetData("Started"))
		{
			print ("Deteriorator Added");
			SetOneShotTimer("DeteriorateTimer",DETERIORATE_TIMER);
			//print ("simTime: " + ShockGame.SimTime());
			SetData("Started",1);
		}
		else
			DeteriorateItems();
	}

	function OnObjectAdded()
	{
		local item = message().data;
		//print(ShockGame.GetArchetypeName(item) + " was added to player");
		
		RemoveLinks(item);
	}
	
	function OnObjectRemoved()
	{
		local item = message().data;
		//print(ShockGame.GetArchetypeName(item) + " was removed from player");
		
		if (!Link.AnyExist(linkkind("Target"),self,item))
		{
			SetData(item + "_removed",ShockGame.SimTime());
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
			
			//print ("Deteriating " + lObj);
			
			local isGoodies = isArchetype(lObj,-49) || isArchetype(lObj,-90);
						
			if (isGoodies)
				Deteriorate(lObj);
		}
	}
	
	//Compares an items removal time with the current sim time
	//If it's due to be deteriorated, it removes some items from it's stacks
	function Deteriorate(item)
	{
		if (Link.AnyExist(linkkind("Contains"),"Player",item))
		{
			ShockGame.AddText("Removing inventory item " + item, "Player");
			RemoveLinks(item);
			return;
		}
	
		local removalTime = GetData(item + "_removed");
		
		local timeDiff = ShockGame.SimTime() - removalTime;
		
		ShockGame.AddText("Time diff for " + ShockGame.GetArchetypeName(item) + " (" + item + ") is " + (timeDiff / 1000),"Player");
		
		local numRemovals = (timeDiff / 1000) / DETERIORATE_RATE;
		
		//print ("numRemovals: " + numRemovals + " (timeDiff: " + timeDiff + ")" );
			
		if (numRemovals > 0)
		{
			ReduceStackSize(item,numRemovals);
			
			//Refresh removal timer
			SetData(item + "_removed",ShockGame.SimTime());
		}
	}
	
	function OnTimer()
	{
		DeteriorateItems();
	
		//Restart Counter
		SetOneShotTimer("DeteriorateTimer",DETERIORATE_TIMER);
		//ShockGame.AddText("simTime: " + ShockGame.SimTime(),"Player");
	}
	
	function isArchetype(obj,type)
	{	
		return obj == type || Object.Archetype(obj) == type || Object.Archetype(obj) == Object.Archetype(type) || Object.InheritsFrom(obj,type);
	}
	
	function ReduceStackSize(item,amount)
	{
		//print("Reducing stack count for " + item + " by " + amount);
		local stackcount = Property.Get(item,"StackCount");
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
			//print ("Added");
			SetData("Started",1);
			local deteriator = Object.Create("Deteriorator");
			//print ("deteriator: " + deteriator);
			SetData("DeteriatorObj",deteriator);
		}
	}

	function OnContainer()
	{
		local deteriator = GetData("DeteriatorObj");
	
		if (!deteriator)
			return;
			
		//print ("Deteriator!");
	
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