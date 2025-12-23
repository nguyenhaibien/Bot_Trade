//+------------------------------------------------------------------+
//| M5_Scalper_EA.mq5                                                 |
//+------------------------------------------------------------------+
#property strict

#include <Trade/Trade.mqh>
CTrade trade;

// ===== INPUT =====
input double LotSize = 0.1;
input int    Slippage = 10;
input int    Magic = 202501;

// ===== GLOBAL =====
datetime lastBarTime = 0;
bool isBreakeven = false;

// ===== PIP CALC =====
double PipValue()
{
   if(StringFind(_Symbol, "XAU") >= 0) return Point * 10;
   if(StringFind(_Symbol, "BTC") >= 0) return Point * 10;
   return Point * 10;
}

// ===== CHECK NEW BAR =====
bool IsNewBar()
{
   datetime t = iTime(_Symbol, PERIOD_M5, 0);
   if(t != lastBarTime)
   {
      lastBarTime = t;
      return true;
   }
   return false;
}

// ===== EMA =====
double EMA(int period)
{
   return iMA(_Symbol, PERIOD_M5, period, 0, MODE_EMA, PRICE_CLOSE, 1);
}

// ===== RSI =====
double RSI()
{
   return iRSI(_Symbol, PERIOD_M5, 14, PRICE_CLOSE, 1);
}

// ===== ADX =====
double ADX()
{
   return iADX(_Symbol, PERIOD_M5, 14, PRICE_CLOSE, MODE_MAIN, 1);
}

// ===== CHECK OPEN POSITION =====
bool HasPosition()
{
   for(int i=0;i<PositionsTotal();i++)
   {
      if(PositionGetTicket(i))
      {
         if(PositionGetInteger(POSITION_MAGIC)==Magic &&
            PositionGetString(POSITION_SYMBOL)==_Symbol)
            return true;
      }
   }
   return false;
}

// ===== ON TICK =====
void OnTick()
{
   if(_Period != PERIOD_M5) return;
   if(!IsNewBar()) return;

   double ema10 = EMA(10);
   double ema21 = EMA(21);
   double ema50 = EMA(50);

   double open1  = iOpen(_Symbol, PERIOD_M5, 1);
   double close1 = iClose(_Symbol, PERIOD_M5, 1);
   double high1  = iHigh(_Symbol, PERIOD_M5, 1);
   double low1   = iLow(_Symbol, PERIOD_M5, 1);

   bool uptrend = ema10 > ema21 && ema21 > ema50;
   bool downtrend = ema10 < ema21 && ema21 < ema50;

   bool bearish = close1 < open1;
   bool bullish = close1 > open1;

   double adx = ADX();
   bool hasTrend = adx > 20;

   double pip = PipValue();
   double sl = pip * (StringFind(_Symbol,"XAU")>=0 ? 50 : 5);
   double tp = pip * (StringFind(_Symbol,"XAU")>=0 ? 100 : 10);

   // ===== BUY =====
   if(uptrend && bearish && close1 < ema10 && close1 > ema21 && hasTrend)
   {
      if(!HasPosition() || isBreakeven)
      {
         trade.SetExpertMagicNumber(Magic);
         trade.Buy(LotSize, _Symbol, Ask, Ask-sl, Ask+tp);
         isBreakeven = false;
      }
   }

   // ===== SELL =====
   if(downtrend && bullish && close1 > ema10 && close1 < ema21 && hasTrend)
   {
      if(!HasPosition() || isBreakeven)
      {
         trade.SetExpertMagicNumber(Magic);
         trade.Sell(LotSize, _Symbol, Bid, Bid+sl, Bid-tp);
         isBreakeven = false;
      }
   }

   // ===== BREAKEVEN =====
   for(int i=0;i<PositionsTotal();i++)
   {
      if(PositionGetTicket(i))
      {
         if(PositionGetInteger(POSITION_MAGIC)!=Magic) continue;

         double entry = PositionGetDouble(POSITION_PRICE_OPEN);
         double stop  = PositionGetDouble(POSITION_SL);
         double price = PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY ? Bid : Ask;

         double R = MathAbs(entry - stop);
         if(!isBreakeven && MathAbs(price-entry) >= R)
         {
            trade.PositionModify(PositionGetTicket(i), entry,
               PositionGetDouble(POSITION_TP));
            isBreakeven = true;
         }
      }
   }
}
