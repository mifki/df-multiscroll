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
#include "df/world.h"
#include "df/construction.h"
#include "df/graphic.h"
#include "df/enabler.h"
#include "df/viewscreen_dwarfmodest.h"
#include "df/renderer.h"
#include "renderer_twbt.h"

using namespace DFHack;
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

CGEventRef MyEventTapCallBack (CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon)
{
    if ((int)type < 0)
        return NULL;
    if (type != kCGEventScrollWheel)
        return event;

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
    bool nextgen = r->is_twbt();
    /*int dispx, dispy;

    if (nextgen)
    {
        dispx = r->gdispx;
        dispy = r->gdispy;
    }
    else
    {
        dispx = r->dispx;
        dispy = r->dispy;
    }*/

    int dx = accdx / 16;
    int dy = accdy / 16;

    if (nextgen && zooming)
    {
        if (dy > 0)
        {
            accdy -= dy*16;

            r->needs_zoom = 1;
            r->needs_reshape = true;
        }
        if (dy < 0)
        {
            accdx -= dx*16;
            accdy -= dy*16;

            renderer_cool *r = (renderer_cool*)enabler->renderer;
            r->needs_zoom = -1;
            r->needs_reshape = true;
        }

        return NULL;
    }

    if (dx || dy)
    {
        accdx -= dx*16;
        accdy -= dy*16;

        *window_x -= dx;
        *window_y -= dy;

        int mx = world->map.x_count;
        int my = world->map.y_count;
        int w = nextgen ? r->gdimxfull : gps->dimx;
        int h = nextgen ? r->gdimyfull : gps->dimy;

        if (dx < 0) //map moves to the left
        {
            int addw;

            if (nextgen)
                addw = 0;
            else
            {
                int sidewidth;
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

                addw = sidewidth + 2;
            }

            if (mx > w - addw)
            {
                if (*window_x > mx - w + addw)
                    *window_x = mx - w + addw;
            }
            else
                *window_x = 0;
        }
        else if (*window_x <= 0)
            *window_x = 0;

        int addh = nextgen ? 0 : 2;

        if (my > h - addh)
        {
            if (*window_y <= 0)
                *window_y = 0;
            else if (*window_y > my - h + addh)
                *window_y = my - h + addh;
        }
        else
            *window_y = 0;
    }

    return NULL;
}

DFhackCExport command_result plugin_init ( color_ostream &out, vector <PluginCommand> &commands)
{
    if (!enabler->renderer->uses_opengl())
    {
        out.color(COLOR_RED);
        out << "MultiScroll: OpenGL renderer is required" << std::endl;
        out.color(COLOR_RESET);
        return CR_OK;        
    }

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