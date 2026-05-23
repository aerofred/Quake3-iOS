//
//  sys_ios.m
//  Quake3-iOS
//
//  Created by Tom Kidd on 11/11/19.
//  Copyright © 2019 Tom Kidd. All rights reserved.
//  Some portions originally Seth Kingsley, January 2008.

#import <Foundation/Foundation.h>
#include "sys_local.h"
#include "qcommon.h"

#if TARGET_OS_TV
#import "Quake3_tvOS-Swift.h"
#else
#import "Quake3_iOS-Swift.h"
#endif

#include <SDL_syswm.h>

extern SDL_Window *SDL_window;

qboolean Sys_LowPhysicalMemory(void) {
    return qtrue;
}

void Sys_UnloadGame( void ) {
}

void Sys_Error(const char *error, ...) {
    extern void Sys_Exit(int ex);
    
    NSString *errorString;
    va_list ap;
    
    va_start(ap, error);
    errorString = [[NSString alloc] initWithFormat:[NSString stringWithCString:error encoding:NSUTF8StringEncoding]
                                          arguments:ap];
    va_end(ap);

    Sys_UnloadGame();
    
    exit(1);
}

void Sys_Warn(const char *warning, ...) {
    NSString *warningString;
    va_list ap;
    
    va_start(ap, warning);
    warningString = [[NSString alloc] initWithFormat:[NSString stringWithCString:warning encoding:NSUTF8StringEncoding]
                                            arguments:ap];
    va_end(ap);
}

UIViewController* GetSDLViewController(SDL_Window *sdlWindow) {
    SDL_SysWMinfo systemWindowInfo;
    SDL_VERSION(&systemWindowInfo.version);
    if ( ! SDL_GetWindowWMInfo(sdlWindow, &systemWindowInfo)) {
        // error handle?
        return nil;
    }
    UIWindow *appWindow = systemWindowInfo.info.uikit.window;
    UIViewController *rootVC = appWindow.rootViewController;
    return rootVC;
}

void Sys_AddControls(SDL_Window *sdlWindow) {
    #if !TARGET_OS_TV
        // adding on-screen controls -tkidd
        SDL_uikitviewcontroller *rootVC = (SDL_uikitviewcontroller *)GetSDLViewController(sdlWindow);
        NSLog(@"root VC = %@",rootVC);

        [rootVC installOnScreenControls];
    #endif
}

void Sys_ToggleControls(SDL_Window *sdlWindow) {
    #if !TARGET_OS_TV
    SDL_uikitviewcontroller *rootVC = (SDL_uikitviewcontroller *)GetSDLViewController(sdlWindow);
    [rootVC toggleControls:Key_GetCatcher( ) & KEYCATCH_UI];
    #endif
}

void Sys_ShowPauseMenu( qboolean visible ) {
    #if !TARGET_OS_TV
    if ( !SDL_window ) {
        return;
    }
    SDL_uikitviewcontroller *rootVC = (SDL_uikitviewcontroller *)GetSDLViewController( SDL_window );
    void (^showBlock)(void) = ^{
        [rootVC setPauseMenuVisible:visible ? YES : NO];
    };
    if ( [NSThread isMainThread] ) {
        showBlock();
    } else {
        dispatch_async( dispatch_get_main_queue(), showBlock );
    }
    #endif
}

static int iosSafeAreaTop = 0;
static int iosSafeAreaLeft = 0;
static int iosSafeAreaBottom = 0;
static int iosSafeAreaRight = 0;

static int iosViewportX = 0;
static int iosViewportY = 0;
static int iosViewportWidth = 0;
static int iosViewportHeight = 0;
static float iosViewportXScale = 1.0f;
static float iosViewportYScale = 1.0f;
static float iosViewportXBias = 0.0f;
static float iosViewportYBias = 0.0f;
static int iosLastVidWidth = 0;
static int iosLastVidHeight = 0;

void Sys_UpdateViewport4x3( int vidWidth, int vidHeight ) {
    int availWidth;
    int availHeight;
    int viewWidth;
    int viewHeight;

    iosLastVidWidth = vidWidth;
    iosLastVidHeight = vidHeight;

    if ( vidWidth <= 0 || vidHeight <= 0 ) {
        return;
    }

    /*
     * Use the full framebuffer (not the safe area) so the 4:3 view is as tall
     * as the screen allows. Native controls still use safeAreaInsets in Swift.
     */
    availWidth = vidWidth;
    availHeight = vidHeight;

    /* Largest 4:3 rect; on landscape this uses full screen height. */
    if ( availWidth * 3 > availHeight * 4 ) {
        viewHeight = availHeight;
        viewWidth = ( availHeight * 4 ) / 3;
    } else {
        viewWidth = availWidth;
        viewHeight = ( availWidth * 3 ) / 4;
    }

    viewWidth &= ~1;
    viewHeight &= ~1;

    iosViewportWidth = viewWidth;
    iosViewportHeight = viewHeight;
    iosViewportX = ( vidWidth - viewWidth ) / 2;
    iosViewportY = ( vidHeight - viewHeight ) / 2;

    iosViewportXScale = (float)viewWidth / 640.0f;
    iosViewportYScale = (float)viewHeight / 480.0f;
    iosViewportXBias = (float)iosViewportX;
    iosViewportYBias = (float)iosViewportY;
}

void Sys_GetViewport4x3( int *x, int *y, int *width, int *height ) {
    if ( x ) {
        *x = iosViewportX;
    }
    if ( y ) {
        *y = iosViewportY;
    }
    if ( width ) {
        *width = iosViewportWidth;
    }
    if ( height ) {
        *height = iosViewportHeight;
    }
}

void Sys_GetViewport640Mapping( float *xscale, float *yscale, float *xbias, float *ybias ) {
    if ( xscale ) {
        *xscale = iosViewportXScale;
    }
    if ( yscale ) {
        *yscale = iosViewportYScale;
    }
    if ( xbias ) {
        *xbias = iosViewportXBias;
    }
    if ( ybias ) {
        *ybias = iosViewportYBias;
    }
}

/*
 * QVM cgame/ui scale 640x480 HUD coords to the full framebuffer. Remap that
 * fullscreen pixel space into the iOS 4:3 viewport (letterbox).
 */
void Sys_RemapFullscreenStretchPic( float *x, float *y, float *w, float *h, int vidWidth, int vidHeight ) {
    float fsXScale;
    float fsYScale;
    float xScale;
    float yScale;
    float xBias;
    float yBias;

    if ( vidWidth <= 0 || vidHeight <= 0 ) {
        return;
    }

    Sys_UpdateViewport4x3( vidWidth, vidHeight );
    Sys_GetViewport640Mapping( &xScale, &yScale, &xBias, &yBias );

    fsXScale = (float)vidWidth / 640.0f;
    fsYScale = (float)vidHeight / 480.0f;

    if ( x ) {
        *x = xBias + ( *x / fsXScale ) * xScale;
    }
    if ( y ) {
        *y = yBias + ( *y / fsYScale ) * yScale;
    }
    if ( w ) {
        *w = ( *w / fsXScale ) * xScale;
    }
    if ( h ) {
        *h = ( *h / fsYScale ) * yScale;
    }
}

void Sys_SetSafeAreaInsets( int top, int left, int bottom, int right ) {
    iosSafeAreaTop = top;
    iosSafeAreaLeft = left;
    iosSafeAreaBottom = bottom;
    iosSafeAreaRight = right;

    if ( iosLastVidWidth > 0 && iosLastVidHeight > 0 ) {
        Sys_UpdateViewport4x3( iosLastVidWidth, iosLastVidHeight );
    }
}

int Sys_SafeAreaTop( void ) {
    return iosSafeAreaTop;
}

int Sys_SafeAreaLeft( void ) {
    return iosSafeAreaLeft;
}

int Sys_SafeAreaBottom( void ) {
    return iosSafeAreaBottom;
}

int Sys_SafeAreaRight( void ) {
    return iosSafeAreaRight;
}


void GLimp_SetGamma( unsigned char red[256], unsigned char green[256], unsigned char blue[256] )
{
    // unused in iOS
}

/*
 =================
 Sys_StripAppBundle
 
 Discovers if passed dir is suffixed with the directory structure of an iOS
 .app bundle. If it is, the .app directory structure is stripped off the end and
 the result is returned. If not, dir is returned untouched.
 =================
 */
char *Sys_StripAppBundle( char *dir )
{
    static char cwd[MAX_OSPATH];
    
    Q_strncpyz(cwd, dir, sizeof(cwd));
    if(!strstr(Sys_Basename(cwd), ".app"))
        return dir;
    Q_strncpyz(cwd, Sys_Dirname(cwd), sizeof(cwd));
    return cwd;
}

/*
 ==============
 Sys_Dialog
 ==============
 */
dialogResult_t Sys_Dialog( dialogType_t type, const char *message, const char *title ) { return 0; }
