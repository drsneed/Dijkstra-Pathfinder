module RoadSim;

import derelict.sdl.sdl;
import derelict.sdl.image;
import std.string : toStringz;

import RoadTool;

void main()
{
	DerelictSDL.load();
	DerelictSDLImage.load();
	scope(exit)
	{
		DerelictSDL.unload();
		DerelictSDLImage.unload();
	}

	SDL_Init( SDL_INIT_VIDEO );
	SDL_Surface* screen;
	SDL_Event event;
	bool running = true;
	void resize(int width, int height)
	{
		screen = SDL_SetVideoMode(width, height, 32, SDL_HWSURFACE | SDL_DOUBLEBUF | SDL_RESIZABLE);
	}
	
	resize(800, 800);
	SDL_WM_SetCaption("Path finding algorithm demonstration".toStringz(), null);
	auto roadTool = new RoadTool(screen, &event);
	while( running )
	{
		while(SDL_PollEvent(&event))
		{
			if(event.type == SDL_QUIT) running = false;
			if(event.type == SDL_KEYDOWN && event.key.keysym.sym == SDLK_ESCAPE) running = false;
			if(event.type == SDL_VIDEORESIZE) resize(event.resize.w, event.resize.h);
			roadTool.handleEvents();
		}
		SDL_FillRect(screen, &screen.clip_rect, SDL_MapRGB(screen.format, 0x76, 0x8d, 0xb0));
		roadTool.render();
		SDL_Flip( screen );
	}
}