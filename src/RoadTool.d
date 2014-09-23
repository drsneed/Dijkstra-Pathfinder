/*
 *  An implementation of Djikstra's pathfinding algorithm.
 */


module RoadTool;

import derelict.sdl.sdl;
import derelict.sdl.image;
import RoadSim;

import std.stdio;
import std.string : toStringz;
import std.math;
import std.array;

static import std.algorithm;


enum RoadType
{
	vertical,
	horizontal,
	intersection,
	topRight,
	bottomRight,
	bottomLeft,
	topLeft,
	anchor
}

enum NEIGHBOR
{ 
	NORTH   = 0x01, 
	SOUTH   = 0x02, 
	EAST    = 0x04, 
	WEST    = 0x08 
}

public class Edge
{
	private int id;
	private Segment source;
	private Segment destination;
	private int weight;
	
	this(int id, Segment source, Segment destination, int weight)
	{
		this.id = id;
		this.source = source;
		this.destination = destination;
		this.weight = weight;
	}
	
	public int getID() { return id; }
	public Segment getDestination() { return destination; }
	public Segment getSource() { return source; }
	public int getWeight() { return weight; }
	
}

private class Segment
{
	private int left;
	private int right;
	private int top;
	private int bottom;
	private float[2] center;
	private bool anchor;
	private int ID;
	
	private RoadType type;
	private SDL_Rect rect;
	
	public this(int x, int y, RoadType type)
	{
		left = x;
		top = y;
		right = x + 25;
		bottom = y + 25;
		center = [x + 12.5, y + 12.5];
		
		this.type = type;
	}
	public SDL_Rect* toRect()
	{
		SDL_Rect rect1;
		rect1.x = cast(short)left;
		rect1.y = cast(short)top;
		rect1.w = 25;
		rect1.h = 25;
		rect = rect1;
		return &rect;
	}
	public bool equals(Segment segment)
	{
		if( this is segment ) return true;
		auto pos = segment.getPosition();
		if(left == pos[0] && top == pos[1]) return true;
		return false;
	}
	public void setPosition(int x, int y)
	{
		left = x;
		top = y;
		right = x + 25;
		bottom = y + 25;
		center = [x + 12.5, y + 12.5];
	}
	public int[2] getPosition()
	{
		return [left, top];
	}
	public void setAnchor()
	{
		anchor = true;
	}
	public void unsetAnchor()
	{
		anchor = false;
	}
	public bool isAnchor()
	{
		return anchor;
	}
	public void setType(RoadType type)
	{
		this.type = type;
	}
	public RoadType getType()
	{
		return type;
	}
	public void setID(int i)
	{
		ID = i;
	}
	public int getID()
	{
		return ID;
	}
	public int distanceTo(Segment other)
	{
		auto pos = other.getPosition();
		if(pos[0] == left)
		{
			return abs(pos[1] - top);
		}
		return abs(pos[0] - left);
	}
}


class RoadTool
{
	private SDL_Surface* screen;
	private SDL_Event* event;
	private SDL_Surface* roadImg;
	private SDL_Surface* cursorMarker;
	private SDL_Surface* startImg;
	private SDL_Surface* endImg;
	private SDL_Surface* highlight;
	private Segment[] roadSegments;
	private Segment[] tempRoad;
	private Segment[][] tempRoads;
	private Segment[] anchors;
	private Segment[] highlights;
	private bool roadToolActivated;
	private bool constructionInProgress;
	private SDL_Rect[8] roadClips;
	
	private Segment cursorSegment;
	
	private int[2] currentAnchorPos;
	private Segment currentAnchor;
	
	private Segment start;
	private Segment end;
	private bool showStart;
	private bool showEnd;
	
	private bool showHighlights;
	

	
	public this(SDL_Surface* screen, SDL_Event* event)
	{
		this.screen = screen;
		this.event = event;
		
		roadImg = IMG_Load("img/road.png".toStringz());
		cursorMarker = IMG_Load("img/node.png".toStringz());
		startImg = IMG_Load("img/s.png".toStringz());
		endImg = IMG_Load("img/e.png".toStringz());
		highlight = IMG_Load("img/green_highlight.png".toStringz());
		
		for(int i = 0; i < 8; i++)
		{
			roadClips[i].x = 0;
			roadClips[i].y = cast(short)( i * 25 );
			roadClips[i].w = 25;
			roadClips[i].h = 25;
		}
		roadToolActivated = true;
		cursorSegment = new Segment(0, 0, RoadType.anchor);
		currentAnchor = cursorSegment;
		start = null;
		end = null;
	}
	private int snap(int i )
	{
		return i - ( i % 25 );
	}
	private uint[2] checkNeighbors(Segment segment)
	{
		auto pos = segment.getPosition();
		uint output;
		uint count;
		foreach(seg; roadSegments)
		{
			auto pos2 = seg.getPosition();
			if(pos[0] == pos2[0] && pos[1] - 25 == pos2[1]){ output |= NEIGHBOR.NORTH; count++; }
			if(pos[0] == pos2[0] && pos[1] + 25 == pos2[1]){ output |= NEIGHBOR.SOUTH; count++; }
			if(pos[1] == pos2[1] && pos[0] - 25 == pos2[0]){ output |= NEIGHBOR.WEST; count++; }
			if(pos[1] == pos2[1] && pos[0] + 25 == pos2[0]){ output |= NEIGHBOR.EAST; count++; }
		}
		return [output, count];	
	}					
	public void handleEvents( )
	{
		if( event.type == SDL_MOUSEBUTTONDOWN )
		{
			if( event.button.button == SDL_BUTTON_LEFT )
			{
				if( roadToolActivated )
				{
					// if there are no temporary road segments
					if(tempRoad.length == 0)
					{
						// if there are no temporary roads in the queue
						if( tempRoads.length == 0)
						{
							currentAnchorPos = cursorSegment.getPosition();
							currentAnchor = new Segment(currentAnchorPos[0], currentAnchorPos[1], RoadType.anchor);
							currentAnchor.setAnchor();
							anchors ~= currentAnchor;
							// need to change
							constructionInProgress = true;
						} else {
							completeSequence();
							// Conpletely finished. Save the whole road
						}
					} else {
						// finished one portion of the road. need to reset anchor and save portion of road to another array.
						currentAnchor = tempRoad[$-1];
						tempRoad = tempRoad[0 .. $-1];
						currentAnchor.setAnchor();
						currentAnchor.setType(RoadType.anchor);
						currentAnchorPos = currentAnchor.getPosition();
						anchors ~= currentAnchor;
						tempRoads ~= tempRoad;
						tempRoad.clear();
					}	
				}
			}
			if( event.button.button == SDL_BUTTON_RIGHT )
			{
				if( tempRoads.length > 0 )
				{
					--tempRoads.length;
					--anchors.length;
					currentAnchorPos = anchors[$-1].getPosition();
					tempRoad.clear();
				}
				else {
					tempRoad.clear();
					anchors.clear();
					constructionInProgress = false;
				}
			}
		
		}
		if( event.type == SDL_MOUSEMOTION )
		{	
			auto x = snap(event.motion.x);
			auto y = snap(event.motion.y);
			if( roadToolActivated ) cursorSegment.setPosition( x, y );
			if( constructionInProgress )
			{
				Segment[] tempRoad1;				
				int xDistance = x - currentAnchorPos[0];
				int yDistance = y - currentAnchorPos[1];
				if(!(xDistance == 0 && yDistance == 0))
				{
					if( abs(xDistance) > abs(yDistance) )
					{
						// horizontal road
						//currentAnchor.setType(RoadType.horizontal);
						auto xPos = currentAnchorPos[0];
						for(int i = 0; i < abs(xDistance / 25); i++ )
						{
							xPos = xDistance < 0 ? xPos - 25 : xPos + 25;
							tempRoad1 ~= new Segment(xPos,  currentAnchorPos[1], RoadType.horizontal);
						}
					} else {
						// vertical

						//currentAnchor.setType(RoadType.vertical);
						auto yPos = currentAnchorPos[1];
						for(int i = 0; i < abs(yDistance / 25); i++ )
						{
							yPos = yDistance < 0 ? yPos - 25 : yPos + 25;
							tempRoad1 ~= new Segment(currentAnchorPos[0],  yPos, RoadType.vertical);
						}
					}
					tempRoad1[$-1].setType(RoadType.anchor);
					tempRoad = tempRoad1;
				}
				
			} else {
		
			}
		}
		if( event.type == SDL_KEYDOWN )
		{
			if( event.key.keysym.sym == SDLK_s )
			{
				if(! constructionInProgress )
				{
					int x, y; SDL_GetMouseState(&x, &y);
					x = snap(x); y = snap(y);
					
					auto seg = getSegmentByPosition(x, y);
					if(seg !is null)
					{
						showStart = true;
						start = seg;
						if(!seg.isAnchor())
						{
							seg.setAnchor();
							anchors ~= seg;
						}
					}
					else {
						showStart = false;
						start = null;
					}
				}
			}
			if( event.key.keysym.sym == SDLK_e )
			{
				if(! constructionInProgress )
				{
					int x, y; SDL_GetMouseState(&x, &y);
					x = snap(x); y = snap(y);
					
					auto seg = getSegmentByPosition(x, y);
					if(seg !is null)
					{
						showEnd = true;
						end = seg;
						if(!seg.isAnchor())
						{
							seg.setAnchor();
							anchors ~= seg;
						}
					}
					else {
						showEnd = false;
						end = null;
					}
				}
			}
			if( event.key.keysym.sym == SDLK_h )
			{
				showHighlights = !showHighlights;
			}
			if( event.key.keysym.sym == SDLK_SPACE )
			{
				runPathfinder();
			}
			if( event.key.keysym.sym == SDLK_F1 )
			{
				roadSegments.clear();
				anchors.clear();
				highlights.clear();
				start = null;
				end = null;
				showStart = false;
				showEnd = false;
			}
		}
					
	}

	private Segment getSegmentByPosition(int x, int y)
	{
		foreach( segment; roadSegments )
		{
			auto pos = segment.getPosition();
			if(pos[0] == x && pos[1] == y)
			{
				return segment;
			}
		}
		return null;
	}
		
	private void runPathfinder()
	{
		Edge[] edges;
		if( constructionInProgress ) return;
		if( start is null || end is null ) return;
		int id;
		foreach( node1; anchors )
		{
			foreach(node2; anchors )
			{
				bool good = true;
				if(node1.equals(node2))
				{
					good = false;
					continue;
				}
				auto pos1 = node1.getPosition();
				auto pos2 = node2.getPosition();
				int x = pos1[0], y = pos1[1];
				int distance;
				if(pos1[0] == pos2[0]) // aligned vertically
				{
					distance = abs(pos1[1] - pos2[1]);
					y = pos1[1] > pos2[1] ? y - 25 : y + 25;
				
					while(y != pos2[1])
					{	
						auto node = getSegmentByPosition(x, y);
						if(!node || node.getType() != RoadType.vertical || node.isAnchor() )
						{
							good = false;
							break;
						}
						y = pos1[1] > pos2[1] ? y - 25 : y + 25;
					}
				}
				else if( pos1[1] == pos2[1] )
				{
					distance = abs(pos1[0] - pos2[0]);
					x = pos1[0] > pos2[0] ? x - 25 : x + 25;
					while(x != pos2[0])
					{	
						auto node = getSegmentByPosition(x, y);
						if(!node || node.getType() != RoadType.horizontal || node.isAnchor() )
						{
							good = false;
							break;
						}
						x = pos1[0] > pos2[0] ? x - 25 : x + 25;
					}
				}
				else good = false;
				
				if( good ) 
				{
					edges ~= new Edge(++id, node1, node2, distance);
				}
				
			}	
		}	
		PathFinder pf = new PathFinder( anchors, edges );
		pf.execute(start);
		Segment[] path = pf.getPath(end);
		highlights.clear();
		foreach(idx, vertex; path )
		{
			
			auto pos1 = vertex.getPosition();
			highlights ~= new Segment(pos1[0], pos1[1], RoadType.intersection);
			if(idx+1 < path.length )
			{
				auto pos2 = path[idx+1].getPosition();
				if(pos1[1] == pos2[1])
				{
					int x1 = pos1[0];
					x1 = pos1[0] > pos2[0] ? x1 - 25 : x1 + 25;
					while(x1 != pos2[0])
					{	
						highlights ~= new Segment(x1, pos1[1], RoadType.intersection);
						x1 = pos1[0] > pos2[0] ? x1 - 25 : x1 + 25;
					}
				}
				else if(pos1[0] == pos2[0])
				{
					int y1 = pos1[1];
					y1 = pos1[1] > pos2[1] ? y1 - 25 : y1 + 25;
					while(y1 != pos2[1])
					{
						highlights ~= new Segment(pos1[0], y1, RoadType.intersection);
						y1 = pos1[1] > pos2[1] ? y1 - 25 : y1 + 25;
					}
				}
				else
				{
					writeln("Strange that you see me.");
				}
			}
			
		}
		showHighlights = true;

		
	}
	public void activate()
	{
		roadToolActivated = true;
	}
	public void deactivate()
	{
		roadToolActivated = false;
	}
	public bool isActivated()
	{
		return roadToolActivated;
	}
	private void completeSequence()
	{
		constructionInProgress = false;
		foreach( road; tempRoads )
		{
			roadSegments ~= road;
		}
		tempRoads.clear();
		roadSegments ~= anchors;
		// re-evaluation of all road segments
		Segment[] tempSegments;
		anchors.clear();
		foreach(segment; roadSegments)
		{
			bool isDup;
			foreach(s; tempSegments)
			{
				if(segment.equals(s))
				{
					isDup = true;
				}
			}
			if(!isDup) tempSegments ~= segment;
		}
		roadSegments = tempSegments;
		
		foreach(s; roadSegments)
		{
			s.unsetAnchor();
			auto p2ix = checkNeighbors(s);
			auto neighbors = p2ix[0];
			auto count = p2ix[1];
			
			if( count > 2 )
			{
				s.setType(RoadType.intersection);
				s.setAnchor();
				anchors ~= s;
			}
			else if( (neighbors & NEIGHBOR.NORTH) &&  (neighbors & NEIGHBOR.EAST) &&
			   !(neighbors & NEIGHBOR.SOUTH) && !(neighbors & NEIGHBOR.WEST) )
			   {
						s.setType(RoadType.topRight);
						s.setAnchor();
						anchors ~= s;
			   }
			else if( (neighbors & NEIGHBOR.NORTH) && !(neighbors & NEIGHBOR.EAST) &&
			   !(neighbors & NEIGHBOR.SOUTH) &&  (neighbors & NEIGHBOR.WEST) )
			   {
						s.setType(RoadType.topLeft);
						s.setAnchor();
						anchors ~= s;
			   }
			else if(!(neighbors & NEIGHBOR.NORTH) && !(neighbors & NEIGHBOR.EAST) &&
			    (neighbors & NEIGHBOR.SOUTH) &&  (neighbors & NEIGHBOR.WEST) )
			    {
						s.setType(RoadType.bottomLeft);
						s.setAnchor();
						anchors ~= s;
				}
			else if(!(neighbors & NEIGHBOR.NORTH) &&  (neighbors & NEIGHBOR.EAST) &&
			    (neighbors & NEIGHBOR.SOUTH) && !(neighbors & NEIGHBOR.WEST) )
			    {
						s.setType(RoadType.bottomRight);
						s.setAnchor();
						anchors ~= s;
				}
				
			else if(!(neighbors & NEIGHBOR.NORTH) &&  (neighbors & NEIGHBOR.EAST) &&
					!(neighbors & NEIGHBOR.SOUTH) &&  (neighbors & NEIGHBOR.WEST) )
				{
						s.setType(RoadType.horizontal);
				}
				
			else if( (neighbors & NEIGHBOR.NORTH) && !(neighbors & NEIGHBOR.EAST) &&
					 (neighbors & NEIGHBOR.SOUTH) && !(neighbors & NEIGHBOR.WEST) )
				{
						s.setType(RoadType.vertical);
				}
			else if( (neighbors & NEIGHBOR.NORTH) ||  (neighbors & NEIGHBOR.SOUTH) )
					 
				{
						s.setType(RoadType.vertical);
						s.setAnchor();
						anchors ~= s;
				}
			else if( (neighbors & NEIGHBOR.WEST) || (neighbors & NEIGHBOR.EAST) )
					 
				{
						s.setType(RoadType.horizontal);
						s.setAnchor();
						anchors ~= s;
				}	
		}
		
	}
							
	public void render()
	{
		foreach( segment; roadSegments )
		{

			SDL_BlitSurface(roadImg, &roadClips[segment.getType()], screen, segment.toRect() );
		}
		if( constructionInProgress )
		{
			foreach( road; tempRoads )
			{
				foreach(segment; road)
				{
					SDL_BlitSurface(roadImg, &roadClips[segment.getType()], screen, segment.toRect() );
				}
			}
			foreach( segment; tempRoad )
			{
				SDL_BlitSurface(roadImg, &roadClips[segment.getType()], screen, segment.toRect() );
			}
			foreach( anchor; anchors )
			{
				SDL_BlitSurface(roadImg, &roadClips[anchor.getType()], screen, anchor.toRect() );
			}
			
		}
		if( showStart )
		{
			SDL_BlitSurface(startImg, null, screen, start.toRect());
		}
		if( showEnd )
		{
			SDL_BlitSurface(endImg, null, screen, end.toRect());
		}

		if( showHighlights )
		{
			foreach(square; highlights)
			{
				SDL_BlitSurface(highlight, null, screen, square.toRect() );
			}
		}
		if( roadToolActivated && !constructionInProgress )
		{

			SDL_BlitSurface(roadImg, &roadClips[cursorSegment.getType()], screen, cursorSegment.toRect() );
		}
		
		
	}
}

// pathfinder

public class PathFinder
{
	private Segment[] nodes;
	private Edge[]   edges;
	private Segment[] settledNodes;
	private Segment[] unsettledNodes;
	private Segment[Segment] predecessors;
	private int[Segment] distance;
	
	private Segment dud;
	
	public this( Segment[] segs, Edge[] edgs )
	{
		this.nodes = segs;
		this.edges = edgs;
		
		dud = new Segment(0, 0, RoadType.intersection);
	}
	public void execute(Segment source)
	{
		distance[source] = 0;
		unsettledNodes ~= source;
		while( unsettledNodes.length > 0 )
		{
			Segment node = getMinimum( unsettledNodes );
			settledNodes ~= node;
			int index     = std.algorithm.countUntil(unsettledNodes, node);
			unsettledNodes = std.algorithm.remove(unsettledNodes, index);
			findMinimalDistances(node);
		}
	}
	
	private void findMinimalDistances(Segment node)
	{
		Segment[] adjacentNodes = getNeighbors( node );
		foreach( target; adjacentNodes )
		{
			auto tempDistance = getShortestDistance(node) + getDistance(node, target);
			if( getShortestDistance(target) > tempDistance )
			{
				distance[target] = tempDistance;
				predecessors[target] = node;
				unsettledNodes ~= target;
			}
		}
	}
	
	private int getDistance(Segment node, Segment target)
	{
		foreach(edge; edges)
		{
			if( edge.getSource().equals(node) && edge.getDestination().equals(target) )
			{
				return edge.getWeight();
			}
		}
		throw new Exception("Bug in getDistance");
	}
	
	private Segment[] getNeighbors(Segment node)
	{
		Segment[] neighbors;
		foreach( edge; edges )
		{
			if( edge.getSource().equals(node) && !isSettled( edge.getDestination() ) )
			{
				neighbors ~= edge.getDestination();
			}
		}
		return neighbors;
	}
	
	private Segment getMinimum( Segment[] vertices )
	{
		Segment minimum = null;
		foreach( Segment; vertices )
		{
			if( minimum is null )
			{
				minimum = Segment;
			} else {
				if( getShortestDistance(Segment) < getShortestDistance( minimum ) )
				{
					minimum = Segment;
				}
			}
		}
		return minimum;
	}
	
	private bool isSettled( Segment Segment )
	{
		return !std.algorithm.find(settledNodes, Segment).empty;
	}
	
	private int getShortestDistance( Segment destination )
	{
		int d = distance.get(destination, -1);
		if( d == -1 )
		{
			return int.max;
		} else {
			return d;
		}
	}
	
	public Segment[] getPath( Segment target )
	{
		Segment[] path;
		
		Segment step = target;
		if( predecessors.get(step, dud) == dud )
		{
			return null;
		}
		path ~= step;
		while( predecessors.get(step, dud) != dud )
		{
			step = predecessors[step];
			path ~= step;
		}
		//assert(path.length > 0, "Something is wrong here.");;
		std.algorithm.reverse( path );
		return path;
	}
}