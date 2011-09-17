#ifndef __CUBE_H__
#define __CUBE_H__

#define _FILE_OFFSET_BITS 64

#ifdef __GNUC__
#define gamma __gamma
#endif

#ifdef WIN32
#define _USE_MATH_DEFINES
#endif
#include <cmath>

#ifdef __GNUC__
#undef gamma
#endif

#include <cstring>
#include <cstdio>
#include <cstdlib>
#include <cctype>
#include <cstdarg>
#include <climits>
#include <cassert>
#include <ctime>
#include "of_string.h"
#include "of_shared_ptr.h"

#ifdef WIN32
  #define WIN32_LEAN_AND_MEAN
  #include "windows.h"
  #ifndef _WINDOWS
    #define _WINDOWS
  #endif
  #ifndef __GNUC__
    #include <eh.h>
    #include <dbghelp.h>
  #endif
  #define ZLIB_DLL
#endif

#ifndef STANDALONE
#include <SDL.h>
#include <SDL_image.h>

#define GL_GLEXT_LEGACY
#define __glext_h__
#define NO_SDL_GLEXT
#include <SDL_opengl.h>
#undef __glext_h__
#include "GL/glext.h"
#endif

#include <enet/enet.h>

#include <zlib.h>

#ifdef __sun__
#undef sun
#ifdef queue
  #undef queue
#endif
#define queue __squeue
#endif

#include "tools.h"
#include "geom.h"
#include "ents.h"

#include "iengine.h"
#include "igame.h"

#endif

