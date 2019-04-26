//+------------------------------------------------------------------+
//|                                                       convex.mq5 |
//|                        Copyright 2018, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2018, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"

/**
 * @file convex.mq5
 * @author Muhammad Al Terra
 * @date 2019-04-24
 */
 
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
class point
{
   //class point untuk diturunkan menjadi axes
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
   //class axes untuk menyimpan data yang dibutuhkan saat menggambar
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
      bool operator==(axes &p)
      {
         return getX() == p.getX() && getY() == p.getY()&& getDT() == p.getDT();  
      }
      
      bool isNotDefined()
      {
         return this.getX() == 0 && this.getY() == 0;
      }
};
class pairOfAx
{
   //class pair of axes untuk mempermudah proses penggambaran
   private:
      axes a;
      axes b;
   public:
      pairOfAx()
      {
      }
      pairOfAx(axes &_a, axes & _b)
      {
         a = _a;
         b = _b;
      }
      
      pairOfAx(pairOfAx &p)
      {
         a = p.getA();
         b = p.getB();
      }
      axes getA()
      {
         return a;
      }
      axes getB()
      {
         return b;
      }
      
      bool operator==(pairOfAx &p)
      {
         return a == p.getA() && b == p.getB();
      }
};

class SetOfAx
{
   //set pairs of axes untuk diiterasikan untuk digambar satu per satu
   private:
      pairOfAx list[];
      int neff;
   public:
      SetOfAx()
      {
         neff = 0;
         ArrayResize(list,0);
      }
      
      bool ArraySearch(pairOfAx &p)
      {
         if (neff > 0)
         {
            bool found = false;
            int i = 0;
            while (!found && i < neff)
            {
               if (list[i] == p)
               {
                  found = true;
               }
               i++;
            }
            return found;
         }
         else
         {
            return false;
         }
      }
      
      void addEl(pairOfAx &p)
      {
         if (!ArraySearch(p))
         {
            neff++;
            ArrayResize(list, neff);
            list[neff-1] = p;
         }
      }
      
      int getNeff()
      {
         return neff;
      }
      pairOfAx getElmt(int idx)
      {
         return list[idx];
      }      
};


//Debug function
void sendHelp(axes &a)
{
   Alert(a.getX() + " HELP " + a.getY());
}

double getDistAx(axes &a, axes &b, axes &c)
{
   //mencari jarak suatu titik jika dibanding kan dari sebuah garis dengan titik a,b
   return (0.5)*MathAbs((a.getX()-c.getX())*(b.getY()-a.getY())-(a.getX()-b.getX())*(c.getY()-a.getY()));
}
bool isNewBar()
//Credit: Konstantin Gruzdev
//mengecek apakah bar baru telah terbuat
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
   //mencari tittk terjauh dari sekumpulan titk yang jaraknya dihitung dari sebuah garis dari a dan b
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

void drawTrendline(axes &a, axes &b, int idx)
{
   //fungsi penggambaran trendline untuk mempermudah proses
   string name = "obj_no."+idx;
   if (ObjectCreate(0, name, OBJ_TREND, 0, a.getDT(), a.getY(), b.getDT(), b.getY()))
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
   //fungsi untuk mencari gradien suatu garis
   return (b.getY()-a.getY())/(b.getX()-a.getX());
}

bool isOnSmex(axes &a, axes &b)
{
   //fungsi untuk melihat apakah x nya sama sehingga gradien 0
   return a.getX() == b.getX();
}

void convhull(axes &a, axes &b, axes &list[], int direction)
{
   //main algo
   //draw line between 2 farthest points
   //drawTrendline(a,b);
   axes uplist[];
   axes downlist[];
   if (ArraySize(list) == 0)
   {
      //basis
      //conquer
      pairOfAx temp(a,b);
      Solns.addEl(temp);
      return;
   }
   else
   {
   //group sets of lines on up or down half
      double curGrad = getGradient(a,b);
      int len = ArraySize(list);
      int upC = 0;
      int doC = 0;
      
      //proses divide
      for (int i = 0; i < len; i++)
      {
         if (!isOnSmex(a,list[i]))
         {
            if ((getGradient(a,list[i]) > curGrad) && !a.isNotDefined() && !list[i].isNotDefined())
            {
               ArrayResize(uplist, upC+1);
               uplist[upC] = list[i];
               upC++;
            }
            else if ((getGradient(a,list[i]) < curGrad) && !a.isNotDefined() && !list[i].isNotDefined())
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
      else
      {
         //basis juga
         //conquer
         pairOfAx temp(a,b);
         Solns.addEl(temp);
         return;
      }
   
   //connect ends with farthest points
   //recurse
   //rekursif tergantung dari downlist dan uplist, jika tidak ada titik yang di atas maka direction = 2 jika tidak ada titk yang di bawah maka direction = 1
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
static SetOfAx Solns();
static int count = 0;
//Main loop
void OnTick()
  {
//---
   if (!isNewBar())
   {
      return;
   }
   if (count % 50 != 0)
   {
      count++;
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
   convhull(listofaxl[0], listofaxl[ArraySize(listofaxl)-1], listofaxl, 0);
   convhull(listofaxh[0], listofaxh[ArraySize(listofaxh)-1], listofaxh, 0);
   
   int neff = Solns.getNeff();
   
   for (int i = 0; i < neff; i++)
   {
      //draw all lines
      drawTrendline(Solns.getElmt(i).getA(), Solns.getElmt(i).getB(),i);
   }
      Alert("finish loop");
   count++;
  }
//+------------------------------------------------------------------+
/*Scraps:

      void swap(axes &a, axes& b)
      {
         axes temp = a;
         a = b;
         b = temp;
      }
      
      void sortByX()
      {
         for (int i = 0; i < neff; i++)
         {
            int j = i;
            int min = list[j].getX();
            int idx = j;
            for (j = i; j < neff; j++)
            {
               if (list[j].getX() < min)
               {
                  idx = j;
                  min = list[j].getX();
               }
            }
            //swap(list[idx], list[i]);
            axes temp = list[idx];
            list[idx] = list[i];
            list[i] = temp;
            
         }
      }
      */
