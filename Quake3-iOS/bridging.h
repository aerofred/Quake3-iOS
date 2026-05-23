//
//  bridging.h
//  Quake3-iOS
//
//  Created by Tom Kidd on 7/21/18.
//  Copyright © 2018 Tom Kidd. All rights reserved.
//

#ifndef bridging_h
#define bridging_h

#include "q_shared.h"
#include "keycodes.h"
//#import "AppDelegate.h"
#import "AppDelegate.h"
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Weverything"
#include "SDL_uikitviewcontroller.h"
#include "SDL_uikitappdelegate.h"
#pragma clang diagnostic pop
#include "UIImage-Targa.h"

void Sys_Startup( int argc, char **argv );

void Com_Frame(void);

void CL_KeyEvent(int key, qboolean down, unsigned time);

void CL_AddReliableCommand(const char *cmd, qboolean isDisconnectCmd);

int Sys_Milliseconds (void);

typedef struct {
    int            down[2];        // key nums holding it down
    unsigned    downtime;        // msec timestamp
    unsigned    msec;            // msec down this frame if both a down and up happened
    qboolean    active;            // current state
    qboolean    wasPressed;        // set when down, not cleared when up
} kbutton_t;

void CL_JoystickEvent( int axis, int value, int time );

void CL_MouseEvent( int dx, int dy, int time, qboolean absolute );

kbutton_t    in_strafe;

void Sys_SetHomeDir( const char *newHomeDir );

void Sys_SetSafeAreaInsets( int top, int left, int bottom, int right );
void Sys_UpdateViewport4x3( int vidWidth, int vidHeight );
void Sys_GetViewport4x3( int *x, int *y, int *width, int *height );
int Sys_SafeAreaTop( void );
int Sys_SafeAreaLeft( void );
int Sys_SafeAreaBottom( void );
int Sys_SafeAreaRight( void );

void Cbuf_AddText( const char *text );
void Cbuf_Execute( void );

int Key_GetCatcher( void );

void CL_OpenPauseMenu( void );
void CL_ClosePauseMenu( void );
int CL_IsPauseMenuOpen( void );
void CL_RestartArena( void );
void CL_LeaveArena( void );
void CL_ExitGame( void );
void CL_ExecuteConsole( const char *text );
int CL_GetCvarInt( const char *name );
void CL_GetCvarString( const char *name, char *out, int outSize );
void CL_SetTeam( const char *team );
void CL_SendTeamOrder( const char *message );
int CL_CanManageBots( void );
int CL_CanUseTeamOrders( void );
void CL_BuildServerInfo( char *buf, int bufsize );
void CL_AddBotCommand( const char *name, int skill );
void CL_KickBotByName( const char *name );
int CL_ConnectedBotCount( void );
int CL_ConnectedBotName( int index, char *out, int outSize );

#endif /* bridging_h */
