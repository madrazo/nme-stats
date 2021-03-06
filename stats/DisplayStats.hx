package stats;

import haxe.Timer;
import nme.events.Event;
import nme.events.KeyboardEvent;
import nme.text.TextField;
import nme.text.TextFormat;
import nme.text.TextFieldAutoSize;
import nme.app.Application;
import nme.Lib;

#if cpp
import cpp.vm.Gc;
#else
import nme.system.System;
#end

@:nativeProperty
class DisplayStats extends TextField
{
   public var currentFPS(get,never):Float;

   private static inline var sUpdateTime:Float = 0.5; //sec
   private static inline var sFpsDecimals:Int = 1;
   private static inline var sFpsSmoothing:Float = 0.1; //lerp with previous
   private static inline var sSpikeRangeInSec:Float = 0.00166; //force update if spike
   private static inline var MB_CONVERSION:Float = 9.53674316e-5;
   private static inline var sNumVerboseLevels:Int = 3;
   private var m_timeToChange:Float;
   private var m_isNormalFormat:Bool;
   private var m_currentTime:Float;
   private var m_currentFPS:Float;
   private var m_showFPS:Float;
   private var m_initFrameRate:Float;
   private var m_normalTextFormat:TextFormat;
   private var m_warnTextFormat:TextFormat;
   private var m_showDt:Float;
   private var m_glVerts:Int;
   private var m_glCalls:Int;
   private var m_dt:Float;
   private var m_fpsPrecisionDecimalsPow:Float;
   private var m_dtPrecisionDecimalsPow:Float;
   private var m_memPeak:Float;
   private var m_statsArray:Array<Int>;
   private var m_oldStatsArray:Array<Int>;
   private var m_dirtyText:Bool;
   private var m_verboseLevel:Int;
   private var m_memCurrent:Float;
   #if cpp
   private var m_memReserved:Float;
   #end


   public function new(inX:Float = 10.0, inY:Float = 10.0, inCol:Int = 0x000000, inWarningCol:Int = 0xFF0000, 
      inBackground:Bool = true, inBgCol:Int = 0xDDDDDD)
   {   
      super();
      
      x = inX;
      y = inY;
      selectable = false;
      mouseEnabled = false;
      background = inBackground;
      backgroundColor = inBgCol;
      
      m_normalTextFormat = new TextFormat("_sans", 12, inCol);
      m_warnTextFormat = new TextFormat("_sans", 12, inWarningCol);
      defaultTextFormat = m_normalTextFormat;
      m_isNormalFormat = true;
      m_initFrameRate = Application.initFrameRate;
      m_timeToChange = sUpdateTime;
      
      text = "";
      autoSize = TextFieldAutoSize.LEFT;

      m_fpsPrecisionDecimalsPow = Math.pow(10, sFpsDecimals);
      m_dtPrecisionDecimalsPow = Math.pow(10, 3);
      
      m_statsArray = [0,0,0,0,0,0,0,0];
      m_oldStatsArray = [0,0,0,0,0,0,0,0];

      addEventListener(Event.ENTER_FRAME, onEnter);
      Lib.current.stage.addEventListener(KeyboardEvent.KEY_UP, stage_onKeyUp);

      m_dirtyText = true;
      m_verboseLevel = 2;
   }
   

   function get_currentFPS() : Float
   {
     return m_currentFPS;
   }
   
   public function stage_onKeyUp(e:KeyboardEvent):Void
   {
      if(e.keyCode==nme.ui.Keyboard.SPACE)
      {
        changeVerboseLevel();
      }
      else if(e.keyCode==nme.ui.Keyboard.ESCAPE)
      {
        toggleVisibility();
      }
   }

   // Event Handlers
   private function onEnter(_)
   {
      if (visible)
      {
         var currentTime = haxe.Timer.stamp();
         var dt:Float = (currentTime-m_currentTime);
         var spike:Bool = false;

         if(dt>0.1)
         {
            m_initFrameRate = Lib.stage.frameRate;
            //reinitialize if dt is too big
            dt = 1.0/m_initFrameRate;
         }
         else
         {
            spike = (dt < m_dt-sSpikeRangeInSec);
            if(spike)
            {
               dt = dt*(1.0-sFpsSmoothing)+m_dt * sFpsSmoothing; 
            }
            else
            {
               dt = dt*sFpsSmoothing+m_dt * (1.0-sFpsSmoothing); 
            }
         }
         m_dt = dt;
         m_currentTime = currentTime;
         var fps:Float = 1.0 / dt;
         var showFPS:Float;
         showFPS = Math.round(fps *  m_fpsPrecisionDecimalsPow) / m_fpsPrecisionDecimalsPow;

         m_timeToChange-= dt;
         if (m_timeToChange < 0 || spike)
         {
            m_timeToChange = sUpdateTime;
            if (showFPS != m_showFPS)
            {
               m_dirtyText = true;
               //change color if necessary
               if (showFPS < m_initFrameRate && m_isNormalFormat)
               {
                  m_isNormalFormat = false;
                  defaultTextFormat = m_warnTextFormat;
               }
               else if ( showFPS >= m_initFrameRate && !m_isNormalFormat )
               {
                  m_isNormalFormat = true;
                  defaultTextFormat = m_normalTextFormat;
               }
               m_showDt = Math.round(dt * m_dtPrecisionDecimalsPow) / m_dtPrecisionDecimalsPow;
            }

            //nme_get_glstats( m_statsArray );
            nme.system.System.getGLStats( m_statsArray );
            for (i in 0...8)
            {
               if (m_statsArray[i] != m_oldStatsArray[i])
               {
                  m_dirtyText = true;
                  m_oldStatsArray[i] = m_statsArray[i];
               }
            }

            if(m_dirtyText)
            {
               m_dirtyText = false;
               var vertsTotal:Int = m_statsArray[0] + m_statsArray[2] + m_statsArray[4] + m_statsArray[6];
               var callsTotal:Int = m_statsArray[1] + m_statsArray[3] + m_statsArray[5] + m_statsArray[7];
               var buf = new StringBuf();

               //GL stats
               if(m_verboseLevel>1)
               {
                  buf.add("GL verts: \t\t");
                  buf.add(vertsTotal);
                  buf.add("\n   drawArrays:\t\t\t");
                  buf.add(m_statsArray[0]);
                  buf.add("\n   drawElements:\t");
                  buf.add(m_statsArray[2]);
                  buf.add("\n   v drawArrays:\t\t\t");
                  buf.add(m_statsArray[4]);
                  buf.add("\n   v drawElements:\t");
                  buf.add(m_statsArray[6]);
                  buf.add("\nGL calls: \t\t");
                  buf.add(callsTotal);
                  buf.add("\n   drawArrays:\t\t\t");
                  buf.add(m_statsArray[1]);
                  buf.add("\n   drawElements:\t");
                  buf.add(m_statsArray[3]);
                  buf.add("\n   v drawArrays:\t\t");
                  buf.add(m_statsArray[5]);
                  buf.add("\n   v drawElements:\t");
                  buf.add(m_statsArray[7]);
                  buf.add("\n");
                  buf.add(showFPS);
                  buf.add((fps==Math.ffloor(showFPS)?".0  /  ":"  /  "));
                  buf.add(m_showDt);
               }
               else
               {
                  buf.add("GL verts: \t\t");
                  buf.add(vertsTotal);
                  buf.add("\nGL calls: \t\t");
                  buf.add(callsTotal);
                  buf.add("\n");
                  buf.add(showFPS);
                  buf.add((fps==Math.ffloor(showFPS)?".0  /  ":"  /  "));
                  buf.add(m_showDt);
               }

               //Memory stats
               if(m_verboseLevel>0)
               {
                  #if cpp
                  m_memCurrent = Math.round(Gc.memInfo64(Gc.MEM_INFO_CURRENT) * MB_CONVERSION)/100;
                  #else
                  m_memCurrent = Math.round(System.totalMemory * MB_CONVERSION)/100;
                  if (m_memCurrent > m_memPeak)
                     m_memPeak = m_memCurrent;
                  #end
                  buf.add("\n\nMEM:\t\t\t");
                  buf.add(m_memCurrent);
                  if(m_verboseLevel<=1)
                  {
                     buf.add(" MB");
                  }
               }
               if(m_verboseLevel>1)
               {
                  #if cpp
                  m_memReserved = Math.round(Gc.memInfo64(Gc.MEM_INFO_RESERVED) * MB_CONVERSION)/100;
                  if (m_memReserved > m_memPeak)
                     m_memPeak = m_memReserved;
                  buf.add(" MB\n   reserved:\t");
                  buf.add(m_memReserved);
                  #end
                  buf.add(" MB\n   peak:\t\t\t ");
                  buf.add(m_memPeak);
                  buf.add(" MB");
               }
               text = buf.toString();
            }
            m_currentFPS = fps;
            m_showFPS = showFPS;
         }
      }
   }

   public function toggleVisibility()
   {
      visible = !visible;
      m_dirtyText = true;
   }

   public function changeVerboseLevel()
   {
      if(visible)
      {
         m_verboseLevel = (++m_verboseLevel)%sNumVerboseLevels;
         m_dirtyText = true;
      }
   }

   //private static var nme_get_glstats = nme.PrimeLoader.load("nme_get_glstats", "ov");
}
