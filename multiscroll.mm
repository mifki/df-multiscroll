//
//  twbt.cpp
//  twbt
//
//  Created by Vitaly Pronkin on 14/05/14.
//  Copyright (c) 2014 mifki. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>
#include <stdint.h>
#include <iostream>
#include <map>
#include <vector>
#include "Core.h"
#include "Console.h"
#include "Export.h"
#include "PluginManager.h"
#include "modules/Maps.h"
#include "modules/World.h"
#include "modules/MapCache.h"
#include "modules/Gui.h"
#include "modules/Screen.h"
#include "df/construction.h"
#include "df/graphic.h"
#include "df/enabler.h"
#include "df/viewscreen_dwarfmodest.h"
#include "df/renderer.h"

using df::global::world;
using std::string;
using std::vector;
using df::global::enabler;
using df::global::gps;
using df::global::ui;
using df::global::window_x;
using df::global::window_y;

DFHACK_PLUGIN("multiscroll");

CFMachPortRef etap;
CFRunLoopSourceRef esrc;
color_ostream *out2;

// This is from g_src/renderer_opengl.hpp
struct renderer_opengl : df::renderer
{
    void *sdlscreen;
    int dispx, dispy;
    GLfloat *vertexes, *fg, *bg, *tex;
    int zoom_steps, forced_steps;
    int natural_w, natural_h;
    int off_x, off_y, size_x, size_y;

    virtual void allocate(int tiles) {};
    virtual void init_opengl() {};
    virtual void uninit_opengl() {};
    virtual void draw(int vertex_count) {};
    virtual void opengl_renderer_destructor() {};
    virtual void reshape_gl() {};
};

struct renderer_cool : renderer_opengl
{
    // To know the size of renderer_opengl's fields
    void *dummy;
    GLfloat *gvertexes, *gfg, *gbg, *gtex;
    int gdimx, gdimy, gdimxfull, gdimyfull;
    int gdispx, gdispy;
    bool gupdate;
    float goff_x, goff_y, gsize_x, gsize_y;
    bool needs_reshape;
    int needs_zoom;

    renderer_cool()
    {
    gvertexes=0, gfg=0, gbg=0, gtex=0;
    gdimx=0, gdimy=0;
    gdispx=0, gdispy=0;
    gupdate = 0;
    goff_x=0, goff_y=0, gsize_x=0, gsize_y=0;

    }

    void reshape_graphics();

    virtual void update_tile(int x, int y);
    virtual void draw(int vertex_count);
    virtual void reshape_gl();

    virtual void update_tile_old(int x, int y) {}; //17
    virtual void reshape_gl_old() {}; //18
};

CGEventRef MyEventTapCallBack (CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon)
{
    df::viewscreen * ws = Gui::getCurViewscreen();
    if (!strict_virtual_cast<df::viewscreen_dwarfmodest>(ws))
        return event;

    static float accdx = 0, accdy = 0;
    NSEvent *e = [NSEvent eventWithCGEvent:event];

    static bool zooming;
    if (e.phase == NSEventPhaseBegan || e.momentumPhase == NSEventPhaseBegan)
    {
        accdx = accdy = 0;
        zooming = ([NSEvent modifierFlags] & NSCommandKeyMask);
    }
    if (zooming && !([NSEvent modifierFlags] & NSCommandKeyMask))
        return NULL;

    accdx += [e scrollingDeltaX];
    accdy += [e scrollingDeltaY];


    renderer_cool *r = (renderer_cool*)enabler->renderer;

    int dx = accdx / r->gdispx;
    int dy = accdy / r->gdispy;


    if (zooming)
    {
        if (dy > 0)
        {
            accdx -= dx*r->gdispx;
            accdy -= dy*r->gdispy;

            r->needs_zoom = 1;
            r->needs_reshape = true;
        }
        if (dy < 0)
        {
            accdx -= dx*r->gdispx;
            accdy -= dy*r->gdispy;

            renderer_cool *r = (renderer_cool*)enabler->renderer;
            r->needs_zoom = -1;
            r->needs_reshape = true;
        }

        return NULL;
    }

    if (dx || dy)
    {
        accdx -= dx*r->gdispx;
        accdy -= dy*r->gdispy;

        *window_x -= dx;
        *window_y -= dy;

        int mx = world->map.x_count_block * 16;
        int my = world->map.y_count_block * 16;
        int w = r->gdimxfull, h = r->gdimyfull;

        if (dx < 0) //map moves to the left
        {
/*            int sidewidth;
            uint8_t menu_width, area_map_width;
            Gui::getMenuWidth(menu_width, area_map_width);

            bool menuforced = (ui->main.mode != df::ui_sidebar_mode::Default || df::global::cursor->x != -30000);

            if ((menuforced || menu_width == 1) && area_map_width == 2) // Menu + area map
                sidewidth = 55;
            else if (menu_width == 2 && area_map_width == 2) // Area map only
                sidewidth = 24;
            else if (menu_width == 1) // Wide menu
                sidewidth = 55;
            else if (menuforced || (menu_width == 2 && area_map_width == 3)) // Menu only
                sidewidth = 31; 
            else
                sidewidth = 0;
*/
            if (mx > w)
            {
                if (*window_x > mx - w)
                    *window_x = mx - w;
            }
            else
                *window_x = 0;
        }
        else if (*window_x <= 0)
            *window_x = 0;

        if (my > h)
        {
            if (*window_y <= 0)
                *window_y = 0;
            else if (*window_y > my - h)
                *window_y = my - h;
        }
        else
            *window_y = 0;
    }

    return NULL;
}

DFhackCExport command_result plugin_init ( color_ostream &out, vector <PluginCommand> &commands)
{
    out2 = &out;
    ProcessSerialNumber curPSN;
    GetCurrentProcess(&curPSN);

    etap = CGEventTapCreateForPSN(&curPSN, kCGHeadInsertEventTap, kCGEventTapOptionDefault, CGEventMaskBit(NX_SCROLLWHEELMOVED), MyEventTapCallBack, NULL);
    if (!etap)
        return CR_FAILURE;

    esrc = CFMachPortCreateRunLoopSource(kCFAllocatorSystemDefault, etap, 0);
    if (!esrc)
    {
        CFRelease(etap);
        return CR_FAILURE;
    }

    CFRunLoopAddSource(CFRunLoopGetMain(), esrc, kCFRunLoopCommonModes);
    CGEventTapEnable(etap, 1);

    return CR_OK;
}

DFhackCExport command_result plugin_shutdown ( color_ostream &out )
{
    CGEventTapEnable(etap, 0);    
    CFRunLoopRemoveSource(CFRunLoopGetMain(), esrc, kCFRunLoopCommonModes);
    CFRelease(esrc);
    CFRelease(etap);

    return CR_OK;
}