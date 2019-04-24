//+------------------------------------------------------------------+
//|                                                       convex.mq5 |
//|                        Copyright 2018, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2018, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
class point
{
   private:
      int x;
      double y;
   public:
      point(int _x, double _y)
      {
         x = _x;
         y = _y;
      }
      double getX(){return x;}
      double getY(){return y;}
      void setX(int _x){x = _x;}
      void setY(int _y){y = _y;}
};

class axes : public point
{
   private:
      datetime dtx;
   public:
      axes(datetime d, double price, int idx) : point(idx, price)
      {
         dtx = d;
      }
      axes() : point(0,0)
      {
         dtx = D'2015.01.01 00:00';
      }
      datetime getDT(){return dtx;}
      axes(axes &p) : point(p.getX(), p.getY())
      {
         dtx = p.getDT();
      }
};

double getDistAx(axes &a, axes &b, axes &c)
{
   return (0.5)*MathAbs((a.getX()-c.getX())*(b.getY()-a.getY())-(a.getX()-b.getX())*(c.getY()-a.getY()));
}
bool isNewBar()
//Credit: Konstantin Gruzdev
  {
//--- memorize the time of opening of the last bar in the static variable
   static datetime last_time=0;
//--- current time
   datetime lastbar_time=SeriesInfoInteger(Symbol(),Period(),SERIES_LASTBAR_DATE);

//--- if it is the first call of the function
   if(last_time==0)
     {
      //--- set the time and exit
      last_time=lastbar_time;
      return(false);
     }

//--- if the time differs
   if(last_time!=lastbar_time)
     {
      //--- memorize the time and return true
      last_time=lastbar_time;
      return(true);
     }
//--- if we passed to this line, then the bar is not new; return false
   return(false);
  }

axes findFarthestPoint(axes &a, axes &b, axes &list[])
{
   int len = ArraySize(list);
   double max = getDistAx(a,b,list[0]);
   int crucial = 0;
   for (int i = 0; i < len; i++)
   {
      if (getDistAx(a,b,list[i])> max)
      {
         max = getDistAx(a,b,list[i]);
         crucial = i;
      }
   }
   return list[crucial];
}

void drawTrendline(axes &a, axes &b)
{
   if (ObjectCreate(0, _Symbol, OBJ_TREND, 0, a.getDT(), a.getY(), b.getDT(), b.getY()))
   {
      Alert("Drawn line");  
   }
   else
   {
      Alert("Invalid object creation!");
   }
}

double getGradient(axes &a, axes &b)
{
   return (b.getY()-a.getY())/(b.getX()-a.getX());
}

bool isOnSmex(axes &a, axes &b)
{
   return a.getX() == b.getX();
}

void convhull(axes &a, axes &b, axes &list[], int direction)
{
   //draw line between 2 farthest points
   //drawTrendline(a,b);
   Alert(a.getX());
   Alert(b.getX());
   axes uplist[];
   axes downlist[];
   if (ArraySize(list) == 0)
   {
      return;
   }
   else
   {
   //group sets of lines on up or down half
      double curGrad = getGradient(a,b);
      int len = ArraySize(list);
      int upC = 0;
      int doC = 0;
      for (int i = 0; i < len; i++)
      {
         if (!isOnSmex(a,list[i]))
         {
            if (getGradient(a,list[i]) > curGrad)
            {
               ArrayResize(uplist, upC+1);
               uplist[upC] = list[i];
               upC++;
            }
            else if (getGradient(a,list[i]) < curGrad)
            {
               ArrayResize(downlist, doC+1);
               downlist[doC] = list[i];
               doC++;
            }
         }
      }
   
   
   //find farthest point from line from list of splitted points
      bool flagup = false;
      bool flagdown = false;
      axes farthdown;
      axes farthup;
      if (ArraySize(downlist) != 0)
      {
         farthdown = findFarthestPoint(a,b,downlist);
         flagdown = true;
      }
      
      if (ArraySize(uplist) != 0)
      {
         farthup = findFarthestPoint(a,b,uplist);
         flagup = true;
      }
      
      if (flagup && flagdown)
      {
         direction = 0;
      }
      else if (flagup && !flagdown)
      {
         direction = 1;
      }
      else if (flagdown && !flagup)
      {
         direction = 2;
      }
   
   //connect ends with farthest points
   //recurse
      if (direction == 0)
      {
         convhull(a, farthup, uplist, 1);
         convhull(farthup, b, uplist, 1);
         convhull(a, farthdown, downlist, 2);
         convhull(farthdown, b, downlist, 2);
      }
      else if (direction == 1)
      {
         convhull(a, farthup, uplist, 1);
         convhull(farthup, b, uplist, 1);
      }
      else if (direction == 2)
      {
         convhull(a, farthdown, downlist, 2);
         convhull(farthdown, b, downlist, 2);
      }
    }
}
int OnInit()
  {
//---
   
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   if (!isNewBar())
   {
      return;
   }
   MqlRates rates[];
   axes listofaxh[];
   axes listofaxl[];
   CopyRates(_Symbol, _Period, 0,40, rates);
   int len = ArraySize(rates);
   for (int i = 0; i < len-1; i++)
   {
      ArrayResize(listofaxh, i+1);
      ArrayResize(listofaxl, i+1);
      axes* temp = new axes(rates[i].time, rates[i].low, i);
      axes* temp1 = new axes(rates[i].time, rates[i].high, i);
      listofaxh[i] = temp;
      listofaxl[i] = temp1;
   }
   convhull(listofaxh[0], listofaxh[ArraySize(listofaxh)-1], listofaxh, 0);
   convhull(listofaxl[0], listofaxl[ArraySize(listofaxl)-1], listofaxl, 0);
  }
//+------------------------------------------------------------------+
