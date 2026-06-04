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

#ifdef USE_LOCAL_HEADERS
#	include "SDL.h"
#else
#	include <SDL.h>
#endif

#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>

#include "../client/client.h"
#include "../sys/sys_local.h"

static cvar_t *in_keyboardDebug     = NULL;

static SDL_GameController *gamepad = NULL;
static SDL_Joystick *stick = NULL;

static qboolean mouseAvailable = qfalse;
static qboolean mouseActive = qfalse;

static cvar_t *in_mouse             = NULL;
static cvar_t *in_nograb;

static cvar_t *in_joystick          = NULL;
static cvar_t *in_joystickThreshold = NULL;
static cvar_t *in_joystickNo        = NULL;
static cvar_t *in_joystickUseAnalog = NULL;

static int vidRestartTime = 0;

static int in_eventTime = 0;

static SDL_Window *SDL_window = NULL;

#ifdef IOS
static void IN_IosCalibratePadAxes( void );
static void IN_IosReleaseDigitalStickKeys( void );

static qboolean iosMouseHasLastPos = qfalse;
static int iosMouseLastX = 0;
static int iosMouseLastY = 0;

static void IN_IosResetMousePosition( void )
{
	iosMouseHasLastPos = qfalse;
}

static void IN_IosQueueMouseMotion( int x, int y, int xrel, int yrel )
{
	int dx, dy;

	if( xrel || yrel )
	{
		dx = xrel;
		dy = yrel;
	}
	else
	{
		if( !iosMouseHasLastPos )
		{
			iosMouseLastX = x;
			iosMouseLastY = y;
			iosMouseHasLastPos = qtrue;
			return;
		}

		dx = x - iosMouseLastX;
		dy = y - iosMouseLastY;
		iosMouseLastX = x;
		iosMouseLastY = y;

		if( !dx && !dy )
			return;
	}

	Com_QueueEvent( in_eventTime, SE_MOUSE, dx, dy, 0, NULL );
}
#endif

#define CTRL(a) ((a)-'a'+1)

/*
===============
IN_PrintKey
===============
*/
static void IN_PrintKey( const SDL_Keysym *keysym, keyNum_t key, qboolean down )
{
	if( down )
		Com_Printf( "+ " );
	else
		Com_Printf( "  " );

	Com_Printf( "Scancode: 0x%02x(%s) Sym: 0x%02x(%s)",
			keysym->scancode, SDL_GetScancodeName( keysym->scancode ),
			keysym->sym, SDL_GetKeyName( keysym->sym ) );

	if( keysym->mod & KMOD_LSHIFT )   Com_Printf( " KMOD_LSHIFT" );
	if( keysym->mod & KMOD_RSHIFT )   Com_Printf( " KMOD_RSHIFT" );
	if( keysym->mod & KMOD_LCTRL )    Com_Printf( " KMOD_LCTRL" );
	if( keysym->mod & KMOD_RCTRL )    Com_Printf( " KMOD_RCTRL" );
	if( keysym->mod & KMOD_LALT )     Com_Printf( " KMOD_LALT" );
	if( keysym->mod & KMOD_RALT )     Com_Printf( " KMOD_RALT" );
	if( keysym->mod & KMOD_LGUI )     Com_Printf( " KMOD_LGUI" );
	if( keysym->mod & KMOD_RGUI )     Com_Printf( " KMOD_RGUI" );
	if( keysym->mod & KMOD_NUM )      Com_Printf( " KMOD_NUM" );
	if( keysym->mod & KMOD_CAPS )     Com_Printf( " KMOD_CAPS" );
	if( keysym->mod & KMOD_MODE )     Com_Printf( " KMOD_MODE" );
	if( keysym->mod & KMOD_RESERVED ) Com_Printf( " KMOD_RESERVED" );

	Com_Printf( " Q:0x%02x(%s)\n", key, Key_KeynumToString( key ) );
}

#define MAX_CONSOLE_KEYS 16

/*
===============
IN_IsConsoleKey

TODO: If the SDL_Scancode situation improves, use it instead of
      both of these methods
===============
*/
static qboolean IN_IsConsoleKey( keyNum_t key, int character )
{
	typedef struct consoleKey_s
	{
		enum
		{
			QUAKE_KEY,
			CHARACTER
		} type;

		union
		{
			keyNum_t key;
			int character;
		} u;
	} consoleKey_t;

	static consoleKey_t consoleKeys[ MAX_CONSOLE_KEYS ];
	static int numConsoleKeys = 0;
	int i;

	// Only parse the variable when it changes
	if( cl_consoleKeys->modified )
	{
		char *text_p, *token;

		cl_consoleKeys->modified = qfalse;
		text_p = cl_consoleKeys->string;
		numConsoleKeys = 0;

		while( numConsoleKeys < MAX_CONSOLE_KEYS )
		{
			consoleKey_t *c = &consoleKeys[ numConsoleKeys ];
			int charCode = 0;

			token = COM_Parse( &text_p );
			if( !token[ 0 ] )
				break;

			charCode = Com_HexStrToInt( token );

			if( charCode > 0 )
			{
				c->type = CHARACTER;
				c->u.character = charCode;
			}
			else
			{
				c->type = QUAKE_KEY;
				c->u.key = Key_StringToKeynum( token );

				// 0 isn't a key
				if( c->u.key <= 0 )
					continue;
			}

			numConsoleKeys++;
		}
	}

	// If the character is the same as the key, prefer the character
	if( key == character )
		key = 0;

	for( i = 0; i < numConsoleKeys; i++ )
	{
		consoleKey_t *c = &consoleKeys[ i ];

		switch( c->type )
		{
			case QUAKE_KEY:
				if( key && c->u.key == key )
					return qtrue;
				break;

			case CHARACTER:
				if( c->u.character == character )
					return qtrue;
				break;
		}
	}

	return qfalse;
}

/*
===============
IN_TranslateSDLToQ3Key
===============
*/
static keyNum_t IN_TranslateSDLToQ3Key( SDL_Keysym *keysym, qboolean down )
{
	keyNum_t key = 0;

	if( keysym->scancode >= SDL_SCANCODE_1 && keysym->scancode <= SDL_SCANCODE_0 )
	{
		// Always map the number keys as such even if they actually map
		// to other characters (eg, "1" is "&" on an AZERTY keyboard).
		// This is required for SDL before 2.0.6, except on Windows
		// which already had this behavior.
		if( keysym->scancode == SDL_SCANCODE_0 )
			key = '0';
		else
			key = '1' + keysym->scancode - SDL_SCANCODE_1;
	}
	else if( keysym->sym >= SDLK_SPACE && keysym->sym < SDLK_DELETE )
	{
		// These happen to match the ASCII chars
		key = (int)keysym->sym;
	}
	else
	{
		switch( keysym->sym )
		{
			case SDLK_PAGEUP:       key = K_PGUP;          break;
			case SDLK_KP_9:         key = K_KP_PGUP;       break;
			case SDLK_PAGEDOWN:     key = K_PGDN;          break;
			case SDLK_KP_3:         key = K_KP_PGDN;       break;
			case SDLK_KP_7:         key = K_KP_HOME;       break;
			case SDLK_HOME:         key = K_HOME;          break;
			case SDLK_KP_1:         key = K_KP_END;        break;
			case SDLK_END:          key = K_END;           break;
			case SDLK_KP_4:         key = K_KP_LEFTARROW;  break;
			case SDLK_LEFT:         key = K_LEFTARROW;     break;
			case SDLK_KP_6:         key = K_KP_RIGHTARROW; break;
			case SDLK_RIGHT:        key = K_RIGHTARROW;    break;
			case SDLK_KP_2:         key = K_KP_DOWNARROW;  break;
			case SDLK_DOWN:         key = K_DOWNARROW;     break;
			case SDLK_KP_8:         key = K_KP_UPARROW;    break;
			case SDLK_UP:           key = K_UPARROW;       break;
			case SDLK_ESCAPE:       key = K_ESCAPE;        break;
			case SDLK_KP_ENTER:     key = K_KP_ENTER;      break;
			case SDLK_RETURN:       key = K_ENTER;         break;
			case SDLK_TAB:          key = K_TAB;           break;
			case SDLK_F1:           key = K_F1;            break;
			case SDLK_F2:           key = K_F2;            break;
			case SDLK_F3:           key = K_F3;            break;
			case SDLK_F4:           key = K_F4;            break;
			case SDLK_F5:           key = K_F5;            break;
			case SDLK_F6:           key = K_F6;            break;
			case SDLK_F7:           key = K_F7;            break;
			case SDLK_F8:           key = K_F8;            break;
			case SDLK_F9:           key = K_F9;            break;
			case SDLK_F10:          key = K_F10;           break;
			case SDLK_F11:          key = K_F11;           break;
			case SDLK_F12:          key = K_F12;           break;
			case SDLK_F13:          key = K_F13;           break;
			case SDLK_F14:          key = K_F14;           break;
			case SDLK_F15:          key = K_F15;           break;

			case SDLK_BACKSPACE:    key = K_BACKSPACE;     break;
			case SDLK_KP_PERIOD:    key = K_KP_DEL;        break;
			case SDLK_DELETE:       key = K_DEL;           break;
			case SDLK_PAUSE:        key = K_PAUSE;         break;

			case SDLK_LSHIFT:
			case SDLK_RSHIFT:       key = K_SHIFT;         break;

			case SDLK_LCTRL:
			case SDLK_RCTRL:        key = K_CTRL;          break;

#ifdef __APPLE__
			case SDLK_RGUI:
			case SDLK_LGUI:         key = K_COMMAND;       break;
#else
			case SDLK_RGUI:
			case SDLK_LGUI:         key = K_SUPER;         break;
#endif

			case SDLK_RALT:
			case SDLK_LALT:         key = K_ALT;           break;

			case SDLK_KP_5:         key = K_KP_5;          break;
			case SDLK_INSERT:       key = K_INS;           break;
			case SDLK_KP_0:         key = K_KP_INS;        break;
			case SDLK_KP_MULTIPLY:  key = K_KP_STAR;       break;
			case SDLK_KP_PLUS:      key = K_KP_PLUS;       break;
			case SDLK_KP_MINUS:     key = K_KP_MINUS;      break;
			case SDLK_KP_DIVIDE:    key = K_KP_SLASH;      break;

			case SDLK_MODE:         key = K_MODE;          break;
			case SDLK_HELP:         key = K_HELP;          break;
			case SDLK_PRINTSCREEN:  key = K_PRINT;         break;
			case SDLK_SYSREQ:       key = K_SYSREQ;        break;
			case SDLK_MENU:         key = K_MENU;          break;
			case SDLK_APPLICATION:	key = K_MENU;          break;
			case SDLK_POWER:        key = K_POWER;         break;
			case SDLK_UNDO:         key = K_UNDO;          break;
			case SDLK_SCROLLLOCK:   key = K_SCROLLOCK;     break;
			case SDLK_NUMLOCKCLEAR: key = K_KP_NUMLOCK;    break;
			case SDLK_CAPSLOCK:     key = K_CAPSLOCK;      break;

			default:
				if( !( keysym->sym & SDLK_SCANCODE_MASK ) && keysym->scancode <= 95 )
				{
					// Map Unicode characters to 95 world keys using the key's scan code.
					// FIXME: There aren't enough world keys to cover all the scancodes.
					// Maybe create a map of scancode to quake key at start up and on
					// key map change; allocate world key numbers as needed similar
					// to SDL 1.2.
					key = K_WORLD_0 + (int)keysym->scancode;
				}
				break;
		}
	}

	if( in_keyboardDebug->integer )
		IN_PrintKey( keysym, key, down );

	if( IN_IsConsoleKey( key, 0 ) )
	{
		// Console keys can't be bound or generate characters
		key = K_CONSOLE;
	}

	return key;
}

/*
===============
IN_GobbleMotionEvents
===============
*/
static void IN_GobbleMotionEvents( void )
{
	SDL_Event dummy[ 1 ];
	int val = 0;

	// Gobble any mouse motion events
	SDL_PumpEvents( );
	while( ( val = SDL_PeepEvents( dummy, 1, SDL_GETEVENT,
		SDL_MOUSEMOTION, SDL_MOUSEMOTION ) ) > 0 ) { }

	if ( val < 0 )
		Com_Printf( "IN_GobbleMotionEvents failed: %s\n", SDL_GetError( ) );
}

/*
===============
IN_ActivateMouse
===============
*/
static void IN_ActivateMouse( qboolean isFullscreen )
{
	if (!mouseAvailable || !SDL_WasInit( SDL_INIT_VIDEO ) )
		return;

	if( !mouseActive )
	{
#ifndef IOS
		SDL_SetWindowGrab( SDL_window, SDL_TRUE );
#endif
		IN_GobbleMotionEvents( );
#ifdef IOS
		IN_IosResetMousePosition( );
#endif
	}

	// in_nograb makes no sense in fullscreen mode
	if( !isFullscreen )
	{
		if( in_nograb->modified || !mouseActive )
		{
#ifdef IOS
			// iOS external mice use absolute pointer coordinates.
			SDL_SetRelativeMouseMode( SDL_FALSE );
			SDL_SetWindowGrab( SDL_window, SDL_FALSE );
#else
			if( in_nograb->integer ) {
				SDL_SetRelativeMouseMode( SDL_FALSE );
				SDL_SetWindowGrab( SDL_window, SDL_FALSE );
			} else {
				SDL_SetRelativeMouseMode( SDL_TRUE );
				SDL_SetWindowGrab( SDL_window, SDL_TRUE );
			}
#endif

			in_nograb->modified = qfalse;
		}
	}

	mouseActive = qtrue;
}

/*
===============
IN_DeactivateMouse
===============
*/
static void IN_DeactivateMouse( qboolean isFullscreen )
{
	if( !SDL_WasInit( SDL_INIT_VIDEO ) )
		return;

	// Always show the cursor when the mouse is disabled,
	// but not when fullscreen
	if( !isFullscreen )
		SDL_ShowCursor( SDL_TRUE );

	if( !mouseAvailable )
		return;

	if( mouseActive )
	{
		IN_GobbleMotionEvents( );

		SDL_SetWindowGrab( SDL_window, SDL_FALSE );
		SDL_SetRelativeMouseMode( SDL_FALSE );

#ifndef IOS
		// Don't warp the mouse unless the cursor is within the window
		if( SDL_GetWindowFlags( SDL_window ) & SDL_WINDOW_MOUSE_FOCUS )
			SDL_WarpMouseInWindow( SDL_window, cls.glconfig.vidWidth / 2, cls.glconfig.vidHeight / 2 );
#else
		IN_IosResetMousePosition( );
#endif

		mouseActive = qfalse;
	}
}

// We translate axes movement into keypresses
static int joy_keys[16] = {
	K_LEFTARROW, K_RIGHTARROW,
	K_UPARROW, K_DOWNARROW,
	K_JOY17, K_JOY18,
	K_JOY19, K_JOY20,
	K_JOY21, K_JOY22,
	K_JOY23, K_JOY24,
	K_JOY25, K_JOY26,
	K_JOY27, K_JOY28
};

// translate hat events into keypresses
// the 4 highest buttons are used for the first hat ...
static int hat_keys[16] = {
	K_JOY29, K_JOY30,
	K_JOY31, K_JOY32,
	K_JOY25, K_JOY26,
	K_JOY27, K_JOY28,
	K_JOY21, K_JOY22,
	K_JOY23, K_JOY24,
	K_JOY17, K_JOY18,
	K_JOY19, K_JOY20
};


struct
{
	qboolean buttons[SDL_CONTROLLER_BUTTON_MAX + 1]; // +1 because old max was 16, current SDL_CONTROLLER_BUTTON_MAX is 15
	unsigned int oldaxes;
	int oldaaxes[MAX_JOYSTICK_AXIS];
	unsigned int oldhats;
} stick_state;

#ifdef IOS
static void IN_IosEnsureJoystickHints( void );
static int IN_IosPickJoystickIndex( int total );
static qboolean IN_IosNameIsAccelerometer( const char *name );
#endif

/*
===============
IN_InitJoystick
===============
*/
static void IN_InitJoystick( void )
{
	int i = 0;
	int total = 0;
	char buf[16384] = "";

	if (gamepad)
		SDL_GameControllerClose(gamepad);

	if (stick != NULL)
		SDL_JoystickClose(stick);

	stick = NULL;
	gamepad = NULL;
	memset(&stick_state, '\0', sizeof (stick_state));

	/* GamepadInputManager may call IN_IosRefreshJoystick before IN_Init(). */
	if ( !in_joystick ) {
		in_joystick = Cvar_Get( "in_joystick", "0", CVAR_ARCHIVE|CVAR_LATCH );
	}
	if ( !in_joystickThreshold ) {
		in_joystickThreshold = Cvar_Get( "joy_threshold", "0.15", CVAR_ARCHIVE );
	}

#ifdef IOS
	IN_IosEnsureJoystickHints();
#endif

	// SDL 2.0.4 requires SDL_INIT_JOYSTICK to be initialized separately from
	// SDL_INIT_GAMECONTROLLER for SDL_JoystickOpen() to work correctly,
	// despite https://wiki.libsdl.org/SDL_Init (retrieved 2016-08-16)
	// indicating SDL_INIT_JOYSTICK should be initialized automatically.
	if (!SDL_WasInit(SDL_INIT_JOYSTICK))
	{
		Com_DPrintf("Calling SDL_Init(SDL_INIT_JOYSTICK)...\n");
		if (SDL_Init(SDL_INIT_JOYSTICK) != 0)
		{
			Com_DPrintf("SDL_Init(SDL_INIT_JOYSTICK) failed: %s\n", SDL_GetError());
			return;
		}
		Com_DPrintf("SDL_Init(SDL_INIT_JOYSTICK) passed.\n");
	}

	if (!SDL_WasInit(SDL_INIT_GAMECONTROLLER))
	{
		Com_DPrintf("Calling SDL_Init(SDL_INIT_GAMECONTROLLER)...\n");
		if (SDL_Init(SDL_INIT_GAMECONTROLLER) != 0)
		{
			Com_DPrintf("SDL_Init(SDL_INIT_GAMECONTROLLER) failed: %s\n", SDL_GetError());
			return;
		}
		Com_DPrintf("SDL_Init(SDL_INIT_GAMECONTROLLER) passed.\n");
	}

	total = SDL_NumJoysticks();
	Com_DPrintf("%d possible joysticks\n", total);

	// Print list and build cvar to allow ui to select joystick.
	for (i = 0; i < total; i++)
	{
		Q_strcat(buf, sizeof(buf), SDL_JoystickNameForIndex(i));
		Q_strcat(buf, sizeof(buf), "\n");
	}

	Cvar_Get( "in_availableJoysticks", buf, CVAR_ROM );

#ifdef IOS
	/* Bluetooth pads (e.g. GameSir X2s in DS4 mode) may be present even when in_joystick is 0. */
	if ( total > 0 && !in_joystick->integer ) {
		Cvar_Set( "in_joystick", "1" );
	}
	/* Load SDL mapping DB entry if present so SDL_GameControllerOpen can succeed. */
	for ( i = 0; i < total; i++ ) {
		SDL_JoystickGUID guid = SDL_JoystickGetDeviceGUID( i );
		char *mapping = SDL_GameControllerMappingForGUID( guid );

		if ( mapping ) {
			SDL_GameControllerAddMapping( mapping );
			SDL_free( mapping );
		}
	}
#endif

	if( !in_joystick->integer ) {
		Com_DPrintf( "Joystick is not active.\n" );
		SDL_QuitSubSystem(SDL_INIT_GAMECONTROLLER);
		return;
	}

	in_joystickNo = Cvar_Get( "in_joystickNo", "0", CVAR_ARCHIVE );
#ifdef IOS
	{
		int pick = IN_IosPickJoystickIndex( total );
		char pickBuf[16];

		if ( pick < 0 ) {
			if ( gamepad ) {
				SDL_GameControllerClose( gamepad );
				gamepad = NULL;
			}
			if ( stick ) {
				SDL_JoystickClose( stick );
				stick = NULL;
			}
			Sys_GamepadEngineLog(
				"ERREUR: aucune manette SDL (seul l'accelerometre iOS ?). Verifiez Bluetooth DS4 puis relancez." );
			Com_DPrintf( "IN_InitJoystick: no usable joystick (accelerometer only?)\n" );
			return;
		}

		if ( pick != in_joystickNo->integer ) {
			Com_sprintf( pickBuf, sizeof( pickBuf ), "%d", pick );
			Cvar_Set( "in_joystickNo", pickBuf );
			in_joystickNo = Cvar_Get( "in_joystickNo", pickBuf, CVAR_ARCHIVE );
		}

		Com_sprintf( pickBuf, sizeof( pickBuf ),
			"IN_InitJoystick: using SDL index %d (%s)",
			pick,
			SDL_JoystickNameForIndex( pick ) ? SDL_JoystickNameForIndex( pick ) : "?" );
		Sys_GamepadEngineLog( pickBuf );
	}
#else
	if( in_joystickNo->integer < 0 || in_joystickNo->integer >= total )
		Cvar_Set( "in_joystickNo", "0" );
#endif

	in_joystickUseAnalog = Cvar_Get( "in_joystickUseAnalog", "0", CVAR_ARCHIVE );

	stick = SDL_JoystickOpen( in_joystickNo->integer );

	if (stick == NULL) {
		Com_DPrintf( "No joystick opened: %s\n", SDL_GetError() );
		return;
	}

	if (SDL_IsGameController(in_joystickNo->integer))
		gamepad = SDL_GameControllerOpen(in_joystickNo->integer);

#ifdef IOS
	if ( gamepad ) {
		/* Digital PAD0_* binds (+moveleft, +forward, +left, …); analog broke strafe (j_side=0). */
		Cvar_Set( "in_joystickUseAnalog", "0" );
		Cvar_Set( "j_side", "0.25" );
		/* j_yaw_axis 0 + HID axis 0 made the player spin; look uses +left/+right keys only. */
		Cvar_Set( "j_yaw_axis", "2" );
		Cvar_Set( "j_yaw", "0" );
		Cvar_Set( "j_pitch_axis", "3" );
		Cvar_Set( "j_pitch", "0" );
		in_joystickUseAnalog = Cvar_Get( "in_joystickUseAnalog", "0", CVAR_ARCHIVE );
		IN_IosCalibratePadAxes();
	}
#endif

	Com_DPrintf( "Joystick %d opened\n", in_joystickNo->integer );
	Com_DPrintf( "Name:       %s\n", SDL_JoystickNameForIndex(in_joystickNo->integer) );
	Com_DPrintf( "Axes:       %d\n", SDL_JoystickNumAxes(stick) );
	Com_DPrintf( "Hats:       %d\n", SDL_JoystickNumHats(stick) );
	Com_DPrintf( "Buttons:    %d\n", SDL_JoystickNumButtons(stick) );
	Com_DPrintf( "Balls:      %d\n", SDL_JoystickNumBalls(stick) );
	Com_DPrintf( "Use Analog: %s\n", in_joystickUseAnalog->integer ? "Yes" : "No" );
	Com_DPrintf( "Is gamepad: %s\n", gamepad ? "Yes" : "No" );

#ifdef IOS
	SDL_JoystickEventState( SDL_ENABLE );
	SDL_GameControllerEventState( SDL_ENABLE );
	Sys_GamepadEngineLog( "SDL joystick/gamecontroller events enabled" );
#else
	SDL_JoystickEventState(SDL_QUERY);
	SDL_GameControllerEventState(SDL_QUERY);
#endif
}

#ifdef IOS
static qboolean IN_IosNameIsAccelerometer( const char *name )
{
	return ( name && Q_stristr( name, "accelerometer" ) != NULL );
}

static void IN_IosEnsureJoystickHints( void )
{
	SDL_SetHint( SDL_HINT_ACCELEROMETER_AS_JOYSTICK, "0" );
}

static int IN_IosPickJoystickIndex( int total )
{
	int i, best = -1, bestScore = -1;
	const char *name;

	for ( i = 0; i < total; i++ ) {
		name = SDL_JoystickNameForIndex( i );
		if ( IN_IosNameIsAccelerometer( name ) ) {
			continue;
		}

		if ( SDL_IsGameController( i ) ) {
			return i;
		}

		if ( name ) {
			if ( Q_stristr( name, "controller" ) || Q_stristr( name, "dualshock" ) ||
				Q_stristr( name, "wireless" ) || Q_stristr( name, "gamepad" ) ||
				Q_stristr( name, "gamesir" ) || Q_stristr( name, "xbox" ) ) {
				if ( bestScore < 50 ) {
					bestScore = 50;
					best = i;
				}
			} else if ( best < 0 ) {
				best = i;
				bestScore = 1;
			}
		} else if ( best < 0 ) {
			best = i;
			bestScore = 1;
		}
	}

	return best;
}

static void IN_IosLogJoystickList( int total )
{
	int i;
	char line[256];
	const char *name;

	Com_sprintf( line, sizeof( line ), "SDL_NumJoysticks=%d:", total );
	Sys_GamepadEngineLog( line );

	for ( i = 0; i < total; i++ ) {
		name = SDL_JoystickNameForIndex( i );
		Com_sprintf( line, sizeof( line ), "  [%d] %s gc=%s%s",
			i,
			name ? name : "(null)",
			SDL_IsGameController( i ) ? "yes" : "no",
			IN_IosNameIsAccelerometer( name ) ? " (SKIP accelerometer)" : "" );
		Sys_GamepadEngineLog( line );
	}
}

/*
===============
IN_IosRefreshJoystick
===============
*/
void IN_IosRefreshJoystick( qboolean openDevice )
{
	int i;
	int total;

	IN_IosEnsureJoystickHints();

	if ( !SDL_WasInit( SDL_INIT_JOYSTICK ) ) {
		SDL_Init( SDL_INIT_JOYSTICK );
	}
	if ( !SDL_WasInit( SDL_INIT_GAMECONTROLLER ) ) {
		SDL_Init( SDL_INIT_GAMECONTROLLER );
	}

	total = SDL_NumJoysticks();
	Com_Printf( "IN_IosRefreshJoystick: SDL_NumJoysticks=%d openDevice=%d in_joystick=%d\n",
		total, openDevice, in_joystick ? in_joystick->integer : 0 );

	IN_IosLogJoystickList( total );

	for ( i = 0; i < total; i++ ) {
		const char *name = SDL_JoystickNameForIndex( i );
		Com_Printf( "  SDL joystick[%d]: %s gameController=%s\n",
			i,
			name ? name : "(null)",
			SDL_IsGameController( i ) ? "yes" : "no" );
	}

	if ( total > 0 && openDevice ) {
		if ( !Com_ZoneInitialized() ) {
			Com_DPrintf( "IN_IosRefreshJoystick: defer open (zone not ready)\n" );
			return;
		}
		IN_InitJoystick();
		Com_Printf( "IN_IosRefreshJoystick: opened=%s gamepad=%s stick=%s\n",
			( gamepad || stick ) ? "yes" : "no",
			gamepad ? "yes" : "no",
			stick ? "yes" : "no" );

		/* Clear stale joystick axis state; look/move use PAD0 digital binds via IN_PadMove. */
		if ( gamepad || stick ) {
			int a;

			for ( a = 0; a < MAX_JOYSTICK_AXIS; a++ ) {
				CL_JoystickEvent( a, 0, Sys_Milliseconds() );
			}
			if ( gamepad ) {
				IN_IosCalibratePadAxes();
			}
			Com_Printf( "IN_IosRefreshJoystick: axes cleared, sticks use PAD0 binds\n" );
		}
	}
}

void IN_IosCloseJoystick( void )
{
	int a;

	if ( gamepad ) {
		SDL_GameControllerClose( gamepad );
		gamepad = NULL;
	}

	if ( stick ) {
		SDL_JoystickClose( stick );
		stick = NULL;
	}

	memset( &stick_state, '\0', sizeof( stick_state ) );
	IN_IosReleaseDigitalStickKeys();

	for ( a = 0; a < MAX_JOYSTICK_AXIS; a++ ) {
		CL_JoystickEvent( a, 0, Sys_Milliseconds() );
	}
}

int Sys_SDLGamepadOpened( void )
{
	if ( gamepad ) {
		return 2;
	}
	if ( stick ) {
		return 1;
	}
	return 0;
}
#endif

/*
===============
IN_ShutdownJoystick
===============
*/
static void IN_ShutdownJoystick( void )
{
	if ( !SDL_WasInit( SDL_INIT_GAMECONTROLLER ) )
		return;

	if ( !SDL_WasInit( SDL_INIT_JOYSTICK ) )
		return;

	if (gamepad)
	{
		SDL_GameControllerClose(gamepad);
		gamepad = NULL;
	}

	if (stick)
	{
		SDL_JoystickClose(stick);
		stick = NULL;
	}

	SDL_QuitSubSystem(SDL_INIT_GAMECONTROLLER);
	SDL_QuitSubSystem(SDL_INIT_JOYSTICK);
}


static qboolean KeyToAxisAndSign(int keynum, int *outAxis, int *outSign)
{
	char *bind;

	if (!keynum)
		return qfalse;

	bind = Key_GetBinding(keynum);

	if (!bind || *bind != '+')
		return qfalse;

	*outSign = 0;

	if (Q_stricmp(bind, "+forward") == 0)
	{
		*outAxis = j_forward_axis->integer;
		*outSign = j_forward->value > 0.0f ? 1 : -1;
	}
	else if (Q_stricmp(bind, "+back") == 0)
	{
		*outAxis = j_forward_axis->integer;
		*outSign = j_forward->value > 0.0f ? -1 : 1;
	}
	else if (Q_stricmp(bind, "+moveleft") == 0)
	{
		*outAxis = j_side_axis->integer;
		*outSign = j_side->value > 0.0f ? -1 : 1;
	}
	else if (Q_stricmp(bind, "+moveright") == 0)
	{
		*outAxis = j_side_axis->integer;
		*outSign = j_side->value > 0.0f ? 1 : -1;
	}
	else if (Q_stricmp(bind, "+lookup") == 0)
	{
		*outAxis = j_pitch_axis->integer;
		*outSign = j_pitch->value > 0.0f ? -1 : 1;
	}
	else if (Q_stricmp(bind, "+lookdown") == 0)
	{
		*outAxis = j_pitch_axis->integer;
		*outSign = j_pitch->value > 0.0f ? 1 : -1;
	}
	else if (Q_stricmp(bind, "+left") == 0)
	{
		*outAxis = j_yaw_axis->integer;
		*outSign = j_yaw->value > 0.0f ? 1 : -1;
	}
	else if (Q_stricmp(bind, "+right") == 0)
	{
		*outAxis = j_yaw_axis->integer;
		*outSign = j_yaw->value > 0.0f ? -1 : 1;
	}
	else if (Q_stricmp(bind, "+moveup") == 0)
	{
		*outAxis = j_up_axis->integer;
		*outSign = j_up->value > 0.0f ? 1 : -1;
	}
	else if (Q_stricmp(bind, "+movedown") == 0)
	{
		*outAxis = j_up_axis->integer;
		*outSign = j_up->value > 0.0f ? -1 : 1;
	}

	return *outSign != 0;
}

/*
===============
IN_PadMove

Feed PAD0_* keys (GamepadConfig binds) from SDL GameController or, on iOS, a raw
Bluetooth joystick when GameController.framework does not see the pad (GameSir HID).
===============
*/
#ifdef IOS
static void IN_IosLogPadActivity( int buttonIndex, qboolean pressed, int axisIndex, int axisValue );

static int IN_IosScaleStickAxis( Sint16 axis, float threshold )
{
	float f = (float)abs( axis ) / 32767.0f;

	if ( f < threshold ) {
		return 0;
	}

	f = ( f - threshold ) / ( 1.0f - threshold );
	if ( f > 1.0f ) {
		f = 1.0f;
	}

	return (int)( 127.0f * f ) * ( axis < 0 ? -1 : 1 );
}

/*
===============
IN_IosDirectPadMove

DS4 / GameSir on iOS often appear as a raw SDL joystick (not GameController).
Drive j_forward_axis / j_side_axis / j_yaw_axis directly and emit PAD0 keys.
===============
*/
static void IN_IosDirectPadMove( void )
{
	int i, numAxes, numButtons, scaled, axis;
	float threshold, lookThreshold;
	qboolean pressed;
	static qboolean didLog;

	if ( !stick ) {
		return;
	}

	if ( IN_IosNameIsAccelerometer( SDL_JoystickName( stick ) ) ) {
		Sys_GamepadEngineLog( "ERREUR: joystick ouvert = accelerometre iOS, re-scan manette..." );
		IN_ShutdownJoystick();
		IN_InitJoystick();
		if ( !stick || IN_IosNameIsAccelerometer( SDL_JoystickName( stick ) ) ) {
			return;
		}
	}

	SDL_JoystickUpdate();

	threshold = ( in_joystickThreshold && in_joystickThreshold->value > 0.01f )
		? in_joystickThreshold->value : 0.15f;
	lookThreshold = threshold < 0.22f ? 0.22f : threshold;

	if ( !didLog ) {
		char buf[256];
		numAxes = SDL_JoystickNumAxes( stick );
		numButtons = SDL_JoystickNumButtons( stick );
		Com_sprintf( buf, sizeof( buf ),
			"IN_IosDirectPadMove: \"%s\" axes=%d buttons=%d (poll path)",
			SDL_JoystickName( stick ) ? SDL_JoystickName( stick ) : "?",
			numAxes, numButtons );
		Sys_GamepadEngineLog( buf );
		didLog = qtrue;
	}

	numAxes = SDL_JoystickNumAxes( stick );

	/* Left stick -> move (j_side_axis=4, j_forward_axis=1, j_forward=-2). */
	if ( numAxes > 0 ) {
		scaled = IN_IosScaleStickAxis( SDL_JoystickGetAxis( stick, 0 ), threshold );
		if ( scaled != stick_state.oldaaxes[4] ) {
			CL_JoystickEvent( 4, scaled, Sys_Milliseconds() );
			stick_state.oldaaxes[4] = scaled;
		}
	}
	if ( numAxes > 1 ) {
		scaled = -IN_IosScaleStickAxis( SDL_JoystickGetAxis( stick, 1 ), threshold );
		if ( scaled != stick_state.oldaaxes[1] ) {
			CL_JoystickEvent( 1, scaled, Sys_Milliseconds() );
			stick_state.oldaaxes[1] = scaled;
		}
	}

	/* Right stick X -> look (j_yaw_axis=2). */
	if ( numAxes > 2 ) {
		scaled = IN_IosScaleStickAxis( SDL_JoystickGetAxis( stick, 2 ), lookThreshold );
		if ( scaled != stick_state.oldaaxes[2] ) {
			CL_JoystickEvent( 2, scaled, Sys_Milliseconds() );
			stick_state.oldaaxes[2] = scaled;
		}
	}

	/* Triggers on axes 4/5 (common PS4 HID layout). */
	for ( i = 4; i <= 5 && i < numAxes; i++ ) {
		axis = SDL_JoystickGetAxis( stick, i );
		pressed = ( axis > 16384 );
		if ( i == 5 ) {
			if ( pressed != stick_state.buttons[SDL_CONTROLLER_BUTTON_MAX] ) {
				IN_IosLogPadActivity( -1, pressed, i, axis );
				Com_QueueEvent( in_eventTime, SE_KEY, K_PAD0_RIGHTTRIGGER, pressed, 0, NULL );
				stick_state.buttons[SDL_CONTROLLER_BUTTON_MAX] = pressed;
			}
		}
	}

	numButtons = SDL_JoystickNumButtons( stick );
	if ( numButtons > SDL_CONTROLLER_BUTTON_MAX ) {
		numButtons = SDL_CONTROLLER_BUTTON_MAX;
	}

	for ( i = 0; i < numButtons; i++ ) {
		pressed = ( SDL_JoystickGetButton( stick, i ) != 0 );
		if ( pressed != stick_state.buttons[i] ) {
			IN_IosLogPadActivity( i, pressed, -1, 0 );
			Com_QueueEvent( in_eventTime, SE_KEY, K_PAD0_A + i, pressed, 0, NULL );
			stick_state.buttons[i] = pressed;
		}
	}

	/* R2 as button 9 when triggers are buttons not axes. */
	if ( numButtons > 9 ) {
		pressed = ( SDL_JoystickGetButton( stick, 9 ) != 0 );
		if ( pressed != stick_state.buttons[SDL_CONTROLLER_BUTTON_MAX] ) {
			Com_QueueEvent( in_eventTime, SE_KEY, K_PAD0_RIGHTTRIGGER, pressed, 0, NULL );
			stick_state.buttons[SDL_CONTROLLER_BUTTON_MAX] = pressed;
		}
	}
}

static int iosPadStickDir[SDL_CONTROLLER_AXIS_MAX];
static Sint16 iosJoyAxisCenter[MAX_JOYSTICK_AXIS];

static void IN_IosReleaseDigitalStickKeys( void )
{
	static const int negKeys[4] = {
		K_PAD0_LEFTSTICK_LEFT, K_PAD0_LEFTSTICK_UP,
		K_PAD0_RIGHTSTICK_LEFT, K_PAD0_RIGHTSTICK_UP
	};
	static const int posKeys[4] = {
		K_PAD0_LEFTSTICK_RIGHT, K_PAD0_LEFTSTICK_DOWN,
		K_PAD0_RIGHTSTICK_RIGHT, K_PAD0_RIGHTSTICK_DOWN
	};
	int i;

	for ( i = 0; i < 4; i++ ) {
		if ( iosPadStickDir[i] < 0 ) {
			Com_QueueEvent( in_eventTime, SE_KEY, negKeys[i], qfalse, 0, NULL );
		}
		if ( iosPadStickDir[i] > 0 ) {
			Com_QueueEvent( in_eventTime, SE_KEY, posKeys[i], qfalse, 0, NULL );
		}
		iosPadStickDir[i] = 0;
	}
}

static void IN_IosCalibratePadAxes( void )
{
	int i, n;

	if ( !stick ) {
		return;
	}

	SDL_GameControllerUpdate();
	SDL_JoystickUpdate();

	memset( iosJoyAxisCenter, 0, sizeof( iosJoyAxisCenter ) );
	n = SDL_JoystickNumAxes( stick );
	if ( n > MAX_JOYSTICK_AXIS ) {
		n = MAX_JOYSTICK_AXIS;
	}
	for ( i = 0; i < n; i++ ) {
		iosJoyAxisCenter[i] = SDL_JoystickGetAxis( stick, i );
	}

	IN_IosReleaseDigitalStickKeys();
}

static Sint16 IN_IosGetPadAxisFromJoystick( int joyAxis )
{
	Sint16 raw;

	if ( !stick || joyAxis < 0 || joyAxis >= SDL_JoystickNumAxes( stick ) ) {
		return 0;
	}
	if ( joyAxis >= MAX_JOYSTICK_AXIS ) {
		return 0;
	}

	raw = SDL_JoystickGetAxis( stick, joyAxis );
	return raw - iosJoyAxisCenter[joyAxis];
}

static Sint16 IN_IosGetPadAxis( SDL_GameControllerAxis axis )
{
	Sint16 v = 0;
	int joyAxis = -1;

	if ( gamepad ) {
		v = SDL_GameControllerGetAxis( gamepad, axis );

		if ( stick ) {
			SDL_GameControllerButtonBind bind =
				SDL_GameControllerGetBindForAxis( gamepad, axis );

			if ( bind.bindType == SDL_CONTROLLER_BINDTYPE_AXIS ) {
				joyAxis = bind.value.axis;
			}
		}
	}

	if ( joyAxis < 0 ) {
		joyAxis = (int)axis;
	}

	if ( stick && joyAxis >= 0 ) {
		Sint16 jv = IN_IosGetPadAxisFromJoystick( joyAxis );

		/* iOS: SDL_GameController poll is often zero; use mapped HID relative to rest. */
		if ( abs( jv ) > abs( v ) + 400 || ( v == 0 && jv != 0 ) ) {
			v = jv;
		}
	}

	return v;
}

static Sint16 IN_IosGetPadTrigger( SDL_GameControllerAxis axis )
{
	Sint16 v = 0;
	int joyAxis = -1;

	if ( gamepad ) {
		v = SDL_GameControllerGetAxis( gamepad, axis );

		if ( stick ) {
			SDL_GameControllerButtonBind bind =
				SDL_GameControllerGetBindForAxis( gamepad, axis );

			if ( bind.bindType == SDL_CONTROLLER_BINDTYPE_AXIS ) {
				joyAxis = bind.value.axis;
			}
		}
	}

	if ( joyAxis < 0 ) {
		joyAxis = (int)axis;
	}

	if ( stick && joyAxis >= 0 && joyAxis < SDL_JoystickNumAxes( stick ) ) {
		Sint16 jv = SDL_JoystickGetAxis( stick, joyAxis );

		if ( jv > v ) {
			v = jv;
		}
	}

	return v;
}

static void IN_IosPadAxisDigitalKeys( Sint16 raw, float threshold, int negKey, int posKey, int *dirState )
{
	int dir = 0;
	float norm = (float)raw / 32767.0f;

	if ( norm > threshold ) {
		dir = 1;
	} else if ( norm < -threshold ) {
		dir = -1;
	}

	if ( *dirState == dir ) {
		return;
	}

	if ( *dirState < 0 ) {
		Com_QueueEvent( in_eventTime, SE_KEY, negKey, qfalse, 0, NULL );
	}
	if ( *dirState > 0 ) {
		Com_QueueEvent( in_eventTime, SE_KEY, posKey, qfalse, 0, NULL );
	}
	if ( dir < 0 ) {
		Com_QueueEvent( in_eventTime, SE_KEY, negKey, qtrue, 0, NULL );
	}
	if ( dir > 0 ) {
		Com_QueueEvent( in_eventTime, SE_KEY, posKey, qtrue, 0, NULL );
	}

	*dirState = dir;
}

static void IN_IosPadMoveDigitalSticks( void )
{
	float moveThresh = 0.18f;
	float lookThresh = 0.24f;

	if ( in_joystickThreshold && in_joystickThreshold->value > 0.01f ) {
		moveThresh = in_joystickThreshold->value;
	}
	if ( moveThresh < 0.18f ) {
		moveThresh = 0.18f;
	}

	IN_IosPadAxisDigitalKeys(
		IN_IosGetPadAxis( SDL_CONTROLLER_AXIS_LEFTX ),
		moveThresh, K_PAD0_LEFTSTICK_LEFT, K_PAD0_LEFTSTICK_RIGHT, &iosPadStickDir[0] );
	IN_IosPadAxisDigitalKeys(
		IN_IosGetPadAxis( SDL_CONTROLLER_AXIS_LEFTY ),
		moveThresh, K_PAD0_LEFTSTICK_UP, K_PAD0_LEFTSTICK_DOWN, &iosPadStickDir[1] );
	IN_IosPadAxisDigitalKeys(
		IN_IosGetPadAxis( SDL_CONTROLLER_AXIS_RIGHTX ),
		lookThresh, K_PAD0_RIGHTSTICK_LEFT, K_PAD0_RIGHTSTICK_RIGHT, &iosPadStickDir[2] );
	IN_IosPadAxisDigitalKeys(
		IN_IosGetPadAxis( SDL_CONTROLLER_AXIS_RIGHTY ),
		lookThresh, K_PAD0_RIGHTSTICK_UP, K_PAD0_RIGHTSTICK_DOWN, &iosPadStickDir[3] );

	{
		static int ltDown, rtDown;
		qboolean lt = ( IN_IosGetPadTrigger( SDL_CONTROLLER_AXIS_TRIGGERLEFT ) > 16384 );
		qboolean rt = ( IN_IosGetPadTrigger( SDL_CONTROLLER_AXIS_TRIGGERRIGHT ) > 16384 );

		if ( lt != ltDown ) {
			Com_QueueEvent( in_eventTime, SE_KEY, K_PAD0_LEFTTRIGGER, lt, 0, NULL );
			ltDown = lt;
		}
		if ( rt != rtDown ) {
			Com_QueueEvent( in_eventTime, SE_KEY, K_PAD0_RIGHTTRIGGER, rt, 0, NULL );
			rtDown = rt;
		}
	}
}

static void IN_IosLogPadActivity( int buttonIndex, qboolean pressed, int axisIndex, int axisValue )
{
	static int lastLogTime;
	int now = Sys_Milliseconds();

	if ( now - lastLogTime < 400 ) {
		return;
	}
	lastLogTime = now;

	if ( buttonIndex >= 0 ) {
		char buf[128];
		Com_sprintf( buf, sizeof( buf ), "input: button[%d] %s (PAD0+%d)",
			buttonIndex, pressed ? "down" : "up", buttonIndex );
		Sys_GamepadEngineLog( buf );
		return;
	}

	if ( axisIndex >= 0 && ( axisValue > 8000 || axisValue < -8000 ) ) {
		char buf[128];
		Com_sprintf( buf, sizeof( buf ), "input: axis[%d]=%d", axisIndex, axisValue );
		Sys_GamepadEngineLog( buf );
	}
}

static int iosJoyMoveFrames = 0;
static int iosJoyEventCount = 0;

static void IN_IosJoyAxisEvent( int axis, Sint16 value )
{
	float threshold, lookThreshold;
	int scaled;

	iosJoyEventCount++;

	threshold = ( in_joystickThreshold && in_joystickThreshold->value > 0.01f )
		? in_joystickThreshold->value : 0.15f;
	lookThreshold = threshold < 0.22f ? 0.22f : threshold;

	switch ( axis ) {
	case 0:
		scaled = IN_IosScaleStickAxis( value, threshold );
		if ( scaled != stick_state.oldaaxes[4] ) {
			CL_JoystickEvent( 4, scaled, Sys_Milliseconds() );
			stick_state.oldaaxes[4] = scaled;
			IN_IosLogPadActivity( -1, qfalse, 0, value );
		}
		break;
	case 1:
		scaled = -IN_IosScaleStickAxis( value, threshold );
		if ( scaled != stick_state.oldaaxes[1] ) {
			CL_JoystickEvent( 1, scaled, Sys_Milliseconds() );
			stick_state.oldaaxes[1] = scaled;
			IN_IosLogPadActivity( -1, qfalse, 1, value );
		}
		break;
	case 2:
		scaled = IN_IosScaleStickAxis( value, lookThreshold );
		if ( scaled != stick_state.oldaaxes[2] ) {
			CL_JoystickEvent( 2, scaled, Sys_Milliseconds() );
			stick_state.oldaaxes[2] = scaled;
			IN_IosLogPadActivity( -1, qfalse, 2, value );
		}
		break;
	case 5:
		{
			qboolean pressed = ( value > 16384 );
			if ( pressed != stick_state.buttons[SDL_CONTROLLER_BUTTON_MAX] ) {
				Com_QueueEvent( in_eventTime, SE_KEY, K_PAD0_RIGHTTRIGGER, pressed, 0, NULL );
				stick_state.buttons[SDL_CONTROLLER_BUTTON_MAX] = pressed;
				IN_IosLogPadActivity( -1, pressed, 5, value );
			}
		}
		break;
	default:
		break;
	}
}

static void IN_IosJoyButtonEvent( int button, qboolean pressed )
{
	if ( button < 0 || button >= SDL_CONTROLLER_BUTTON_MAX ) {
		return;
	}

	iosJoyEventCount++;

	if ( pressed != stick_state.buttons[button] ) {
		int key = K_PAD0_A + button;

		if ( button == 9 ) {
			key = K_PAD0_RIGHTTRIGGER;
		}

		Com_QueueEvent( in_eventTime, SE_KEY, key, pressed, 0, NULL );
		stick_state.buttons[button] = pressed;
		IN_IosLogPadActivity( button, pressed, -1, 0 );
	}
}

void IN_IosDebugPadState( char *buf, int bufsize )
{
	int rawAxis0 = 0;

	if ( buf && bufsize > 0 ) {
		buf[0] = '\0';
	}

	if ( !buf || bufsize < 32 ) {
		return;
	}

	if ( gamepad ) {
		rawAxis0 = IN_IosGetPadAxis( SDL_CONTROLLER_AXIS_LEFTX );
	} else if ( stick && SDL_JoystickNumAxes( stick ) > 0 ) {
		rawAxis0 = SDL_JoystickGetAxis( stick, 0 );
	}

	Com_sprintf( buf, bufsize,
		"engine: stick=%s gamepad=%s joyMoves=%d joyEvents=%d catcher=%d cl.state=%d axis0raw=%d name=%s",
		stick ? "yes" : "no",
		gamepad ? "yes" : "no",
		iosJoyMoveFrames,
		iosJoyEventCount,
		Key_GetCatcher(),
		clc.state,
		rawAxis0,
		( stick && SDL_JoystickName( stick ) ) ? SDL_JoystickName( stick ) : "-" );
}
#endif

static void IN_PadMove( void )
{
	int i;
	int translatedAxes[MAX_JOYSTICK_AXIS];
	qboolean translatedAxesSet[MAX_JOYSTICK_AXIS];

	if ( !gamepad && !stick )
		return;

	if ( gamepad )
		SDL_GameControllerUpdate();
	else
		SDL_JoystickUpdate();

	// check buttons
	for (i = 0; i < SDL_CONTROLLER_BUTTON_MAX; i++)
	{
		qboolean pressed = qfalse;

		if ( gamepad )
			pressed = SDL_GameControllerGetButton( gamepad, (SDL_GameControllerButton)i );
		else if ( i < SDL_JoystickNumButtons( stick ) )
			pressed = ( SDL_JoystickGetButton( stick, i ) != 0 );

		if (pressed != stick_state.buttons[i])
		{
#ifdef IOS
			IN_IosLogPadActivity( i, pressed, -1, 0 );
#endif
			Com_QueueEvent(in_eventTime, SE_KEY, K_PAD0_A + i, pressed, 0, NULL);
			stick_state.buttons[i] = pressed;
		}
	}

#ifdef IOS
	if ( gamepad ) {
		IN_IosPadMoveDigitalSticks();
		iosJoyMoveFrames++;
		return;
	}
#endif

	// must defer translated axes until all real axes are processed
	// must be done this way to prevent a later mapped axis from zeroing out a previous one
	if (in_joystickUseAnalog->integer)
	{
		for (i = 0; i < MAX_JOYSTICK_AXIS; i++)
		{
			translatedAxes[i] = 0;
			translatedAxesSet[i] = qfalse;
		}
	}

	// check axes
	for (i = 0; i < SDL_CONTROLLER_AXIS_MAX; i++)
	{
		int axis;

		if ( gamepad )
			axis = SDL_GameControllerGetAxis( gamepad, (SDL_GameControllerAxis)i );
		else if ( i < SDL_JoystickNumAxes( stick ) )
			axis = SDL_JoystickGetAxis( stick, i );
		else
			continue;
		int oldAxis = stick_state.oldaaxes[i];
		float threshold = in_joystickThreshold->value;

#ifdef IOS
		/* Bluetooth pads: large dead zone on look sticks; strafe needs a moderate zone. */
		if ( gamepad ) {
			if ( i == SDL_CONTROLLER_AXIS_RIGHTX || i == SDL_CONTROLLER_AXIS_RIGHTY ) {
				if ( threshold < 0.32f ) {
					threshold = 0.32f;
				}
			} else if ( i == SDL_CONTROLLER_AXIS_LEFTX ) {
				if ( threshold < 0.20f ) {
					threshold = 0.20f;
				}
			}
		} else if ( i == SDL_CONTROLLER_AXIS_RIGHTX || i == SDL_CONTROLLER_AXIS_RIGHTY ) {
			if ( threshold < 0.22f ) {
				threshold = 0.22f;
			}
		}
#endif

		// Smoothly ramp from dead zone to maximum value
		float f = ((float)abs(axis) / 32767.0f - threshold) / (1.0f - threshold);

		if (f < 0.0f)
			f = 0.0f;

		axis = (int)(32767 * ((axis < 0) ? -f : f));

		if (axis != oldAxis)
		{
#ifdef IOS
			if ( !gamepad ) {
				IN_IosLogPadActivity( -1, qfalse, i, axis );
			}
#endif
			const int negMap[SDL_CONTROLLER_AXIS_MAX] = { K_PAD0_LEFTSTICK_LEFT,  K_PAD0_LEFTSTICK_UP,   K_PAD0_RIGHTSTICK_LEFT,  K_PAD0_RIGHTSTICK_UP, 0, 0 };
			const int posMap[SDL_CONTROLLER_AXIS_MAX] = { K_PAD0_LEFTSTICK_RIGHT, K_PAD0_LEFTSTICK_DOWN, K_PAD0_RIGHTSTICK_RIGHT, K_PAD0_RIGHTSTICK_DOWN, K_PAD0_LEFTTRIGGER, K_PAD0_RIGHTTRIGGER };

			qboolean posAnalog = qfalse, negAnalog = qfalse;
			int negKey = negMap[i];
			int posKey = posMap[i];

			if (in_joystickUseAnalog->integer)
			{
				int posAxis = 0, posSign = 0, negAxis = 0, negSign = 0;

				// get axes and axes signs for keys if available
				posAnalog = KeyToAxisAndSign(posKey, &posAxis, &posSign);
				negAnalog = KeyToAxisAndSign(negKey, &negAxis, &negSign);

				// positive to negative/neutral -> keyup if axis hasn't yet been set
				if (posAnalog && !translatedAxesSet[posAxis] && oldAxis > 0 && axis <= 0)
				{
					translatedAxes[posAxis] = 0;
					translatedAxesSet[posAxis] = qtrue;
				}

				// negative to positive/neutral -> keyup if axis hasn't yet been set
				if (negAnalog && !translatedAxesSet[negAxis] && oldAxis < 0 && axis >= 0)
				{
					translatedAxes[negAxis] = 0;
					translatedAxesSet[negAxis] = qtrue;
				}

				// negative/neutral to positive -> keydown
				if (posAnalog && axis > 0)
				{
					translatedAxes[posAxis] = axis * posSign;
					translatedAxesSet[posAxis] = qtrue;
				}

				// positive/neutral to negative -> keydown
				if (negAnalog && axis < 0)
				{
					translatedAxes[negAxis] = -axis * negSign;
					translatedAxesSet[negAxis] = qtrue;
				}
			}

			// keyups first so they get overridden by keydowns later

			// positive to negative/neutral -> keyup
			if (!posAnalog && posKey && oldAxis > 0 && axis <= 0)
				Com_QueueEvent(in_eventTime, SE_KEY, posKey, qfalse, 0, NULL);

			// negative to positive/neutral -> keyup
			if (!negAnalog && negKey && oldAxis < 0 && axis >= 0)
				Com_QueueEvent(in_eventTime, SE_KEY, negKey, qfalse, 0, NULL);

			// negative/neutral to positive -> keydown
			if (!posAnalog && posKey && oldAxis <= 0 && axis > 0)
				Com_QueueEvent(in_eventTime, SE_KEY, posKey, qtrue, 0, NULL);

			// positive/neutral to negative -> keydown
			if (!negAnalog && negKey && oldAxis >= 0 && axis < 0)
				Com_QueueEvent(in_eventTime, SE_KEY, negKey, qtrue, 0, NULL);

			stick_state.oldaaxes[i] = axis;
		}
	}

	// set translated axes
	if (in_joystickUseAnalog->integer)
	{
		for (i = 0; i < MAX_JOYSTICK_AXIS; i++)
		{
			if (translatedAxesSet[i])
				Com_QueueEvent(in_eventTime, SE_JOYSTICK_AXIS, i, translatedAxes[i], 0, NULL);
		}
	}
}


/*
===============
IN_JoyMove
===============
*/
static void IN_JoyMove( void )
{
	unsigned int axes = 0;
	unsigned int hats = 0;
	int total = 0;
	int i = 0;

#ifdef IOS
	/* Swift GameController path owns input when a pad is attached there. */
	if ( Sys_NativeGamepadActive() ) {
		return;
	}
#endif

	if (gamepad)
	{
		IN_PadMove();
		return;
	}

	if (!stick)
		return;

#ifdef IOS
	iosJoyMoveFrames++;
	/* Raw Bluetooth joystick (DS4 via SDL, GC=0): direct axis/key routing. */
	if ( !gamepad ) {
		IN_IosDirectPadMove();
		return;
	}
#endif

	SDL_JoystickUpdate();

	// update the ball state.
	total = SDL_JoystickNumBalls(stick);
	if (total > 0)
	{
		int balldx = 0;
		int balldy = 0;
		for (i = 0; i < total; i++)
		{
			int dx = 0;
			int dy = 0;
			SDL_JoystickGetBall(stick, i, &dx, &dy);
			balldx += dx;
			balldy += dy;
		}
		if (balldx || balldy)
		{
			// !!! FIXME: is this good for stick balls, or just mice?
			// Scale like the mouse input...
			if (abs(balldx) > 1)
				balldx *= 2;
			if (abs(balldy) > 1)
				balldy *= 2;
			Com_QueueEvent( in_eventTime, SE_MOUSE, balldx, balldy, 0, NULL );
		}
	}

	// now query the stick buttons...
	total = SDL_JoystickNumButtons(stick);
	if (total > 0)
	{
		if (total > ARRAY_LEN(stick_state.buttons))
			total = ARRAY_LEN(stick_state.buttons);
		for (i = 0; i < total; i++)
		{
			qboolean pressed = (SDL_JoystickGetButton(stick, i) != 0);
			if (pressed != stick_state.buttons[i])
			{
				Com_QueueEvent( in_eventTime, SE_KEY, K_JOY1 + i, pressed, 0, NULL );
				stick_state.buttons[i] = pressed;
			}
		}
	}

	// look at the hats...
	total = SDL_JoystickNumHats(stick);
	if (total > 0)
	{
		if (total > 4) total = 4;
		for (i = 0; i < total; i++)
		{
			((Uint8 *)&hats)[i] = SDL_JoystickGetHat(stick, i);
		}
	}

	// update hat state
	if (hats != stick_state.oldhats)
	{
		for( i = 0; i < 4; i++ ) {
			if( ((Uint8 *)&hats)[i] != ((Uint8 *)&stick_state.oldhats)[i] ) {
				// release event
				switch( ((Uint8 *)&stick_state.oldhats)[i] ) {
					case SDL_HAT_UP:
						Com_QueueEvent( in_eventTime, SE_KEY, hat_keys[4*i + 0], qfalse, 0, NULL );
						break;
					case SDL_HAT_RIGHT:
						Com_QueueEvent( in_eventTime, SE_KEY, hat_keys[4*i + 1], qfalse, 0, NULL );
						break;
					case SDL_HAT_DOWN:
						Com_QueueEvent( in_eventTime, SE_KEY, hat_keys[4*i + 2], qfalse, 0, NULL );
						break;
					case SDL_HAT_LEFT:
						Com_QueueEvent( in_eventTime, SE_KEY, hat_keys[4*i + 3], qfalse, 0, NULL );
						break;
					case SDL_HAT_RIGHTUP:
						Com_QueueEvent( in_eventTime, SE_KEY, hat_keys[4*i + 0], qfalse, 0, NULL );
						Com_QueueEvent( in_eventTime, SE_KEY, hat_keys[4*i + 1], qfalse, 0, NULL );
						break;
					case SDL_HAT_RIGHTDOWN:
						Com_QueueEvent( in_eventTime, SE_KEY, hat_keys[4*i + 2], qfalse, 0, NULL );
						Com_QueueEvent( in_eventTime, SE_KEY, hat_keys[4*i + 1], qfalse, 0, NULL );
						break;
					case SDL_HAT_LEFTUP:
						Com_QueueEvent( in_eventTime, SE_KEY, hat_keys[4*i + 0], qfalse, 0, NULL );
						Com_QueueEvent( in_eventTime, SE_KEY, hat_keys[4*i + 3], qfalse, 0, NULL );
						break;
					case SDL_HAT_LEFTDOWN:
						Com_QueueEvent( in_eventTime, SE_KEY, hat_keys[4*i + 2], qfalse, 0, NULL );
						Com_QueueEvent( in_eventTime, SE_KEY, hat_keys[4*i + 3], qfalse, 0, NULL );
						break;
					default:
						break;
				}
				// press event
				switch( ((Uint8 *)&hats)[i] ) {
					case SDL_HAT_UP:
						Com_QueueEvent( in_eventTime, SE_KEY, hat_keys[4*i + 0], qtrue, 0, NULL );
						break;
					case SDL_HAT_RIGHT:
						Com_QueueEvent( in_eventTime, SE_KEY, hat_keys[4*i + 1], qtrue, 0, NULL );
						break;
					case SDL_HAT_DOWN:
						Com_QueueEvent( in_eventTime, SE_KEY, hat_keys[4*i + 2], qtrue, 0, NULL );
						break;
					case SDL_HAT_LEFT:
						Com_QueueEvent( in_eventTime, SE_KEY, hat_keys[4*i + 3], qtrue, 0, NULL );
						break;
					case SDL_HAT_RIGHTUP:
						Com_QueueEvent( in_eventTime, SE_KEY, hat_keys[4*i + 0], qtrue, 0, NULL );
						Com_QueueEvent( in_eventTime, SE_KEY, hat_keys[4*i + 1], qtrue, 0, NULL );
						break;
					case SDL_HAT_RIGHTDOWN:
						Com_QueueEvent( in_eventTime, SE_KEY, hat_keys[4*i + 2], qtrue, 0, NULL );
						Com_QueueEvent( in_eventTime, SE_KEY, hat_keys[4*i + 1], qtrue, 0, NULL );
						break;
					case SDL_HAT_LEFTUP:
						Com_QueueEvent( in_eventTime, SE_KEY, hat_keys[4*i + 0], qtrue, 0, NULL );
						Com_QueueEvent( in_eventTime, SE_KEY, hat_keys[4*i + 3], qtrue, 0, NULL );
						break;
					case SDL_HAT_LEFTDOWN:
						Com_QueueEvent( in_eventTime, SE_KEY, hat_keys[4*i + 2], qtrue, 0, NULL );
						Com_QueueEvent( in_eventTime, SE_KEY, hat_keys[4*i + 3], qtrue, 0, NULL );
						break;
					default:
						break;
				}
			}
		}
	}

	// save hat state
	stick_state.oldhats = hats;

	// finally, look at the axes...
	total = SDL_JoystickNumAxes(stick);
	if (total > 0)
	{
		if (in_joystickUseAnalog->integer)
		{
			if (total > MAX_JOYSTICK_AXIS) total = MAX_JOYSTICK_AXIS;
			for (i = 0; i < total; i++)
			{
				Sint16 axis = SDL_JoystickGetAxis(stick, i);
				float f = ( (float) abs(axis) ) / 32767.0f;
				
				if( f < in_joystickThreshold->value ) axis = 0;

				if ( axis != stick_state.oldaaxes[i] )
				{
					Com_QueueEvent( in_eventTime, SE_JOYSTICK_AXIS, i, axis, 0, NULL );
					stick_state.oldaaxes[i] = axis;
				}
			}
		}
		else
		{
			if (total > 16) total = 16;
			for (i = 0; i < total; i++)
			{
				Sint16 axis = SDL_JoystickGetAxis(stick, i);
				float f = ( (float) axis ) / 32767.0f;
				if( f < -in_joystickThreshold->value ) {
					axes |= ( 1 << ( i * 2 ) );
				} else if( f > in_joystickThreshold->value ) {
					axes |= ( 1 << ( ( i * 2 ) + 1 ) );
				}
			}
		}
	}

	/* Time to update axes state based on old vs. new. */
	if (axes != stick_state.oldaxes)
	{
		for( i = 0; i < 16; i++ ) {
			if( ( axes & ( 1 << i ) ) && !( stick_state.oldaxes & ( 1 << i ) ) ) {
				Com_QueueEvent( in_eventTime, SE_KEY, joy_keys[i], qtrue, 0, NULL );
			}

			if( !( axes & ( 1 << i ) ) && ( stick_state.oldaxes & ( 1 << i ) ) ) {
				Com_QueueEvent( in_eventTime, SE_KEY, joy_keys[i], qfalse, 0, NULL );
			}
		}
	}

	/* Save for future generations. */
	stick_state.oldaxes = axes;
}

/*
===============
IN_ProcessEvents
===============
*/
static void IN_ProcessEvents( void )
{
	SDL_Event e;
	keyNum_t key = 0;
	static keyNum_t lastKeyDown = 0;

	if( !SDL_WasInit( SDL_INIT_VIDEO ) )
			return;

	while( SDL_PollEvent( &e ) )
	{
		switch( e.type )
		{
			case SDL_KEYDOWN:
				if ( e.key.repeat && Key_GetCatcher( ) == 0 )
					break;

				if( ( key = IN_TranslateSDLToQ3Key( &e.key.keysym, qtrue ) ) )
					Com_QueueEvent( in_eventTime, SE_KEY, key, qtrue, 0, NULL );

				if( key == K_BACKSPACE )
					Com_QueueEvent( in_eventTime, SE_CHAR, CTRL('h'), 0, 0, NULL );
				else if( keys[K_CTRL].down && key >= 'a' && key <= 'z' )
					Com_QueueEvent( in_eventTime, SE_CHAR, CTRL(key), 0, 0, NULL );

				lastKeyDown = key;
				break;

			case SDL_KEYUP:
				if( ( key = IN_TranslateSDLToQ3Key( &e.key.keysym, qfalse ) ) )
					Com_QueueEvent( in_eventTime, SE_KEY, key, qfalse, 0, NULL );

				lastKeyDown = 0;
				break;

			case SDL_TEXTINPUT:
				if( lastKeyDown != K_CONSOLE )
				{
					char *c = e.text.text;

					// Quick and dirty UTF-8 to UTF-32 conversion
					while( *c )
					{
						int utf32 = 0;

						if( ( *c & 0x80 ) == 0 )
							utf32 = *c++;
						else if( ( *c & 0xE0 ) == 0xC0 ) // 110x xxxx
						{
							utf32 |= ( *c++ & 0x1F ) << 6;
							utf32 |= ( *c++ & 0x3F );
						}
						else if( ( *c & 0xF0 ) == 0xE0 ) // 1110 xxxx
						{
							utf32 |= ( *c++ & 0x0F ) << 12;
							utf32 |= ( *c++ & 0x3F ) << 6;
							utf32 |= ( *c++ & 0x3F );
						}
						else if( ( *c & 0xF8 ) == 0xF0 ) // 1111 0xxx
						{
							utf32 |= ( *c++ & 0x07 ) << 18;
							utf32 |= ( *c++ & 0x3F ) << 12;
							utf32 |= ( *c++ & 0x3F ) << 6;
							utf32 |= ( *c++ & 0x3F );
						}
						else
						{
							Com_DPrintf( "Unrecognised UTF-8 lead byte: 0x%x\n", (unsigned int)*c );
							c++;
						}

						if( utf32 != 0 )
						{
							if( IN_IsConsoleKey( 0, utf32 ) )
							{
								Com_QueueEvent( in_eventTime, SE_KEY, K_CONSOLE, qtrue, 0, NULL );
								Com_QueueEvent( in_eventTime, SE_KEY, K_CONSOLE, qfalse, 0, NULL );
							}
							else
								Com_QueueEvent( in_eventTime, SE_CHAR, utf32, 0, 0, NULL );
						}
          }
        }
				break;

			case SDL_MOUSEMOTION:
				if( mouseActive )
				{
#ifdef IOS
					if( Key_GetCatcher( ) & KEYCATCH_UI )
						break;
					IN_IosQueueMouseMotion( e.motion.x, e.motion.y, e.motion.xrel, e.motion.yrel );
#else
					if( !e.motion.xrel && !e.motion.yrel )
						break;
					Com_QueueEvent( in_eventTime, SE_MOUSE, e.motion.xrel, e.motion.yrel, 0, NULL );
#endif
				}
				break;

			case SDL_MOUSEBUTTONDOWN:
			case SDL_MOUSEBUTTONUP:
				{
#ifdef IOS
					if( Key_GetCatcher( ) & KEYCATCH_UI )
						break;
#endif
					int b;
					switch( e.button.button )
					{
						case SDL_BUTTON_LEFT:   b = K_MOUSE1;     break;
						case SDL_BUTTON_MIDDLE: b = K_MOUSE3;     break;
						case SDL_BUTTON_RIGHT:  b = K_MOUSE2;     break;
						case SDL_BUTTON_X1:     b = K_MOUSE4;     break;
						case SDL_BUTTON_X2:     b = K_MOUSE5;     break;
						default:                b = K_AUX1 + ( e.button.button - SDL_BUTTON_X2 + 1 ) % 16; break;
					}
					Com_QueueEvent( in_eventTime, SE_KEY, b,
						( e.type == SDL_MOUSEBUTTONDOWN ? qtrue : qfalse ), 0, NULL );
				}
				break;

			case SDL_MOUSEWHEEL:
				if( e.wheel.y > 0 )
				{
					Com_QueueEvent( in_eventTime, SE_KEY, K_MWHEELUP, qtrue, 0, NULL );
					Com_QueueEvent( in_eventTime, SE_KEY, K_MWHEELUP, qfalse, 0, NULL );
				}
				else if( e.wheel.y < 0 )
				{
					Com_QueueEvent( in_eventTime, SE_KEY, K_MWHEELDOWN, qtrue, 0, NULL );
					Com_QueueEvent( in_eventTime, SE_KEY, K_MWHEELDOWN, qfalse, 0, NULL );
				}
				break;

			case SDL_JOYAXISMOTION:
#ifdef IOS
				/* Underlying HID joystick: ignore while SDL_GameController handles the pad. */
				if ( !gamepad && stick && e.jaxis.which == SDL_JoystickInstanceID( stick ) ) {
					IN_IosJoyAxisEvent( e.jaxis.axis, e.jaxis.value );
				}
#endif
				break;

			case SDL_JOYBUTTONDOWN:
#ifdef IOS
				if ( !Sys_NativeGamepadActive() && stick && e.jbutton.which == SDL_JoystickInstanceID( stick ) ) {
					IN_IosJoyButtonEvent( e.jbutton.button, qtrue );
				}
#endif
				break;

			case SDL_JOYBUTTONUP:
#ifdef IOS
				if ( !Sys_NativeGamepadActive() && stick && e.jbutton.which == SDL_JoystickInstanceID( stick ) ) {
					IN_IosJoyButtonEvent( e.jbutton.button, qfalse );
				}
#endif
				break;

			case SDL_CONTROLLERAXISMOTION:
				/* iOS SDL_GameController: IN_JoyMove/IN_PadMove polls axes (digital PAD0 binds). */
				break;

			case SDL_CONTROLLERBUTTONDOWN:
			case SDL_CONTROLLERBUTTONUP:
				/* Buttons handled in IN_PadMove when gamepad is open. */
				break;

			case SDL_JOYDEVICEADDED:
			case SDL_JOYDEVICEREMOVED:
			case SDL_CONTROLLERDEVICEADDED:
			case SDL_CONTROLLERDEVICEREMOVED:
				if (in_joystick->integer)
					IN_InitJoystick();
				break;

			case SDL_QUIT:
				Cbuf_ExecuteText(EXEC_NOW, "quit Closed window\n");
				break;

			case SDL_WINDOWEVENT:
				switch( e.window.event )
				{
					case SDL_WINDOWEVENT_RESIZED:
						{
							int width, height;

							width = e.window.data1;
							height = e.window.data2;

							// ignore this event on fullscreen
							if( cls.glconfig.isFullscreen )
							{
								break;
							}

							// check if size actually changed
							if( cls.glconfig.vidWidth == width && cls.glconfig.vidHeight == height )
							{
								break;
							}

							Cvar_SetValue( "r_customwidth", width );
							Cvar_SetValue( "r_customheight", height );
							Cvar_Set( "r_mode", "-1" );

							// Wait until user stops dragging for 1 second, so
							// we aren't constantly recreating the GL context while
							// he tries to drag...
							vidRestartTime = Sys_Milliseconds( ) + 1000;
						}
						break;

					case SDL_WINDOWEVENT_MINIMIZED:    Cvar_SetValue( "com_minimized", 1 ); break;
					case SDL_WINDOWEVENT_RESTORED:
					case SDL_WINDOWEVENT_MAXIMIZED:    Cvar_SetValue( "com_minimized", 0 ); break;
					case SDL_WINDOWEVENT_FOCUS_LOST:   Cvar_SetValue( "com_unfocused", 1 ); break;
					case SDL_WINDOWEVENT_FOCUS_GAINED: Cvar_SetValue( "com_unfocused", 0 ); break;
				}
				break;
                
#ifdef IOS
                case SDL_FINGERMOTION:
                case SDL_FINGERDOWN:
                case SDL_FINGERUP:
                    if ( Key_GetCatcher( ) & KEYCATCH_UI ) {
#ifdef IOS
                        if ( CL_IsPauseMenuOpen() ) {
                            break;
                        }
#endif
                        float vidWidth = (float)cls.glconfig.vidWidth;
                        float vidHeight = (float)cls.glconfig.vidHeight;
                        float pixelX = e.tfinger.x * vidWidth;
                        float pixelY = e.tfinger.y * vidHeight;
                        float xscale;
                        float yscale;
                        float xbias;
                        float ybias;
                        int menuX;
                        int menuY;

                        Sys_UpdateViewport4x3( cls.glconfig.vidWidth, cls.glconfig.vidHeight );
                        Sys_GetViewport640Mapping( &xscale, &yscale, &xbias, &ybias );

                        menuX = (int)( ( pixelX - xbias ) / xscale );
                        menuY = (int)( ( pixelY - ybias ) / yscale );

                        if ( menuX < 0 ) {
                            menuX = 0;
                        } else if ( menuX > 640 ) {
                            menuX = 640;
                        }

                        if ( menuY < 0 ) {
                            menuY = 0;
                        } else if ( menuY > 480 ) {
                            menuY = 480;
                        }

                        if ( e.type == SDL_FINGERMOTION || e.type == SDL_FINGERDOWN ) {
                            CL_MouseEvent( menuX, menuY, Sys_Milliseconds(), qtrue );
                        }

                    }
                    break;
#endif

			default:
				break;
		}
	}
}

/*
===============
IN_Frame
===============
*/
void IN_Frame( void )
{
	qboolean loading;

#ifdef IOS
	/* Controllers often connect after the engine starts on iOS (GameSir, etc.). */
	if ( !gamepad && !stick )
	{
		static int lastJoyProbe = 0;
		int now = Sys_Milliseconds();

		if ( now - lastJoyProbe > 500 )
		{
			lastJoyProbe = now;
			if ( SDL_NumJoysticks() > 0 )
				IN_InitJoystick();
		}
	}
#endif

	IN_JoyMove( );

	// If not DISCONNECTED (main menu) or ACTIVE (in game), we're loading
	loading = ( clc.state != CA_DISCONNECTED && clc.state != CA_ACTIVE );

	// update isFullscreen since it might of changed since the last vid_restart
	cls.glconfig.isFullscreen = Cvar_VariableIntegerValue( "r_fullscreen" ) != 0;

	if( !cls.glconfig.isFullscreen && ( Key_GetCatcher( ) & KEYCATCH_CONSOLE ) )
	{
		// Console is down in windowed mode
		IN_DeactivateMouse( cls.glconfig.isFullscreen );
	}
	else if( !cls.glconfig.isFullscreen && loading )
	{
		// Loading in windowed mode
		IN_DeactivateMouse( cls.glconfig.isFullscreen );
	}
	else if( !( SDL_GetWindowFlags( SDL_window ) & SDL_WINDOW_INPUT_FOCUS ) )
	{
		// Window not got focus
		IN_DeactivateMouse( cls.glconfig.isFullscreen );
	}
#ifdef IOS
	else if( Key_GetCatcher( ) & KEYCATCH_UI )
	{
		IN_DeactivateMouse( cls.glconfig.isFullscreen );
	}
#endif
	else
		IN_ActivateMouse( cls.glconfig.isFullscreen );

	IN_ProcessEvents( );

	// Set event time for next frame to earliest possible time an event could happen
	in_eventTime = Sys_Milliseconds( );

	// In case we had to delay actual restart of video system
	if( ( vidRestartTime != 0 ) && ( vidRestartTime < Sys_Milliseconds( ) ) )
	{
		vidRestartTime = 0;
		Cbuf_AddText( "vid_restart\n" );
	}
}

/*
===============
IN_Init
===============
*/
void IN_Init( void *windowData )
{
	int appState;

	if( !SDL_WasInit( SDL_INIT_VIDEO ) )
	{
		Com_Error( ERR_FATAL, "IN_Init called before SDL_Init( SDL_INIT_VIDEO )" );
		return;
	}

	SDL_window = (SDL_Window *)windowData;

	Com_DPrintf( "\n------- Input Initialization -------\n" );

	in_keyboardDebug = Cvar_Get( "in_keyboardDebug", "0", CVAR_ARCHIVE );

	// mouse variables
	in_mouse = Cvar_Get( "in_mouse", "1", CVAR_ARCHIVE );
	in_nograb = Cvar_Get( "in_nograb", "0", CVAR_ARCHIVE );

	in_joystick = Cvar_Get( "in_joystick", "0", CVAR_ARCHIVE|CVAR_LATCH );
	in_joystickThreshold = Cvar_Get( "joy_threshold", "0.15", CVAR_ARCHIVE );

#ifndef IOS
	SDL_StartTextInput( );
#else
    SDL_SetHint(SDL_HINT_ACCELEROMETER_AS_JOYSTICK, "0");
    SDL_SetHint(SDL_HINT_TOUCH_MOUSE_EVENTS, "0");
#endif

	mouseAvailable = ( in_mouse->value != 0 );
	IN_DeactivateMouse( Cvar_VariableIntegerValue( "r_fullscreen" ) != 0 );

	appState = SDL_GetWindowFlags( SDL_window );
	Cvar_SetValue( "com_unfocused",	!( appState & SDL_WINDOW_INPUT_FOCUS ) );
	Cvar_SetValue( "com_minimized", appState & SDL_WINDOW_MINIMIZED );

	IN_InitJoystick( );
	Com_DPrintf( "------------------------------------\n" );
}

/*
===============
IN_Shutdown
===============
*/
void IN_Shutdown( void )
{
	SDL_StopTextInput( );

	IN_DeactivateMouse( Cvar_VariableIntegerValue( "r_fullscreen" ) != 0 );
	mouseAvailable = qfalse;

	IN_ShutdownJoystick( );

	SDL_window = NULL;
}

/*
===============
IN_Restart
===============
*/
void IN_Restart( void )
{
	IN_ShutdownJoystick( );
	IN_Init( SDL_window );
}
