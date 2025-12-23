//+------------------------------------------------------------------+
//| M5_Scalper_EA                                                     |
//+------------------------------------------------------------------+
#property strict

#include <Trade/Trade.mqh>
CTrade trade;

// ================= INPUT =================
input double RiskPercent = 1.0;
input int    MagicNumber = 5555;

input int EMA10 = 10;
input int EMA21 = 21;
input int EMA50 = 50;

input int RSILength = 14;
input int RSI_BUY_MIN = 55;
input int RSI_SELL_MAX = 44;

input int ADXLength = 14;
input int ADX_MIN = 20;

// London + NY
input int LondonStart = 7;
input int LondonEnd   = 16;
input int NYStart     = 12;
input int NYEnd       = 21;

// Symbols (multi-symbol)
input string Symbols = "EURUSD,XAUUSD,BTCUSD";

// ================= GLOBAL =================
string symbolList[];
datetime lastBarTime[];

// ================= INIT =================
int OnInit()
{
   int count = StringSplit(Symbols, ',', symbolList);
   ArrayResize(lastBarTime, count);
   return INIT_SUCCEEDED;
}

// ================= LOT CALC =================
double CalcLot(string symbol, double slPips)
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskMoney = balance * RiskPercent / 100.0;

   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double lot = riskMoney / (slPips * tickValue);

   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);

   lot = MathMax(minLot, MathMin(maxLot, lot));
   return NormalizeDouble(lot, 2);
}

// ================= SESSION =================
bool InSession()
{
   MqlDateTime t;
   TimeToStruct(TimeCurrent(), t);

   bool london = (t.hour >= LondonStart && t.hour < LondonEnd);
   bool ny     = (t.hour >= NYStart && t.hour < NYEnd);

   return (london || ny);
}

// ================= PIP =================
double PipValue(string symbol)
{
   if (StringFind(symbol, "XAU") >= 0) return _Point * 1000;
   if (StringFind(symbol, "BTC") >= 0) return _Point * 1000;
   return _Point * 10;
}

// ================= CHECK OPEN TRADE =================
bool HasPosition(string symbol)
{
   return PositionSelect(symbol);
}

// ================= ON TICK =================
void OnTick()
{
   for (int i = 0; i < ArraySize(symbolList); i++)
   {
      string symbol = symbolList[i];
      if (!SymbolSelect(symbol, true)) continue;

      datetime barTime = iTime(symbol, PERIOD_M5, 0);
      if (barTime == lastBarTime[i]) continue;
      lastBarTime[i] = barTime;

      if (!InSession()) continue;
      if (HasPosition(symbol)) { ManageBreakeven(symbol); continue; }

      // === EMA ===
      double ema10 = iMA(symbol, PERIOD_M5, EMA10, 0, MODE_EMA, PRICE_CLOSE, 1);
      double ema21 = iMA(symbol, PERIOD_M5, EMA21, 0, MODE_EMA, PRICE_CLOSE, 1);
      double ema50 = iMA(symbol, PERIOD_M5, EMA50, 0, MODE_EMA, PRICE_CLOSE, 1);

      bool uptrend = ema10 > ema21 && ema21 > ema50;
      bool downtrend = ema10 < ema21 && ema21 < ema50;

      // === Candle ===
      double open = iOpen(symbol, PERIOD_M5, 1);
      double close = iClose(symbol, PERIOD_M5, 1);
      double high = iHigh(symbol, PERIOD_M5, 1);
      double low  = iLow(symbol, PERIOD_M5, 1);

      bool bearish = close < open;
      bool bullish = close > open;

      // === RSI ===
      double rsi = iRSI(symbol, PERIOD_M5, RSILength, PRICE_CLOSE, 1);
      bool rsiBuy = rsi > RSI_BUY_MIN && rsi < 70;
      bool rsiSell = rsi < RSI_SELL_MAX && rsi > 30;

      // === ADX ===
      double adx = iADX(symbol, PERIOD_M5, ADXLength, PRICE_CLOSE, MODE_MAIN, 1);
      if (adx < ADX_MIN) continue;

      // === BUY ===
      if (uptrend && bearish && close < ema10 && close > ema21 && rsiBuy)
         OpenTrade(symbol, ORDER_TYPE_BUY);

      // === SELL ===
      if (downtrend && bullish && close > ema10 && close < ema21 && rsiSell)
         OpenTrade(symbol, ORDER_TYPE_SELL);
   }
}

// ================= OPEN TRADE =================
void OpenTrade(string symbol, ENUM_ORDER_TYPE type)
{
   double pip = PipValue(symbol);
   double slPips = (StringFind(symbol, "XAU") >= 0) ? 50 * pip : 5 * pip;
   double tpPips = slPips * 2;

   double price = (type == ORDER_TYPE_BUY)
                  ? SymbolInfoDouble(symbol, SYMBOL_ASK)
                  : SymbolInfoDouble(symbol, SYMBOL_BID);

   double sl = (type == ORDER_TYPE_BUY) ? price - slPips : price + slPips;
   double tp = (type == ORDER_TYPE_BUY) ? price + tpPips : price - tpPips;

   double lot = CalcLot(symbol, slPips);

   trade.SetExpertMagicNumber(MagicNumber);
   trade.PositionOpen(symbol, type, lot, price, sl, tp);
}

// ================= BREAKEVEN 1R =================
void ManageBreakeven(string symbol)
{
   if (!PositionSelect(symbol)) return;

   double entry = PositionGetDouble(POSITION_PRICE_OPEN);
   double sl = PositionGetDouble(POSITION_SL);
   double tp = PositionGetDouble(POSITION_TP);
   double price = SymbolInfoDouble(symbol, SYMBOL_BID);

   double R = MathAbs(entry - sl);

   if ((PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY && price >= entry + R) ||
       (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && price <= entry - R))
   {
      trade.PositionModify(symbol, entry, tp);
   }
}
