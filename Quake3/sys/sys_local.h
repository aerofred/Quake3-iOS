/*
===========================================================================
Copyright (C) 1999-2005 Id Software, Inc.

This file is part of Quake III Arena source code.

Quake III Arena source code is free software; you can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation; either version 2 of the License,
or (at your option) any later version.

Quake III Arena source code is distributed in the hope that it will be
useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Quake III Arena source code; if not, write to the Free Software
Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
===========================================================================
*/

#include "../qcommon/q_shared.h"
#include "../qcommon/qcommon.h"

#ifndef DEDICATED
#ifdef USE_LOCAL_HEADERS
#	include "SDL_version.h"
#   include "SDL_video.h"
#else
#	include <SDL_version.h>
#   include <SDL_video.h>
#endif
#endif

// Require a minimum version of SDL
#define MINSDL_MAJOR 2
#define MINSDL_MINOR 0
#if SDL_VERSION_ATLEAST( 2, 0, 5 )
#define MINSDL_PATCH 5
#else
#define MINSDL_PATCH 0
#endif

// Console
void CON_Shutdown( void );
void CON_Init( void );
char *CON_Input( void );
void CON_Print( const char *message );

unsigned int CON_LogSize( void );
unsigned int CON_LogWrite( const char *in );
unsigned int CON_LogRead( char *out, unsigned int outSize );

#ifdef __APPLE__
char *Sys_StripAppBundle( char *pwd );
#ifdef IOS
char *Sys_DefaultLibraryPath(void);
void Sys_SetHomeDir( const char *newHomeDir );
void Sys_AddControls(SDL_Window *sdlWindow);
void Sys_ToggleControls(SDL_Window *sdlWindow);
void Sys_ShowPauseMenu( qboolean visible );
void Sys_UpdateViewport4x3( int vidWidth, int vidHeight );
void Sys_GetViewport4x3( int *x, int *y, int *width, int *height );
void Sys_GetViewport640Mapping( float *xscale, float *yscale, float *xbias, float *ybias );
void Sys_RemapFullscreenStretchPic( float *x, float *y, float *w, float *h, int vidWidth, int vidHeight );
void Sys_SetSafeAreaInsets( int top, int left, int bottom, int right );
int Sys_SafeAreaTop( void );
int Sys_SafeAreaLeft( void );
int Sys_SafeAreaBottom( void );
int Sys_SafeAreaRight( void );
#endif
#endif

void Sys_GLimpSafeInit( void );
void Sys_GLimpInit( void );
void Sys_PlatformInit( void );
void Sys_PlatformExit( void );
void Sys_SigHandler( int signal ) __attribute__ ((noreturn));
void Sys_ErrorDialog( const char *error );
void Sys_AnsiColorPrint( const char *msg );

int Sys_PID( void );
qboolean Sys_PIDIsRunning( int pid );
