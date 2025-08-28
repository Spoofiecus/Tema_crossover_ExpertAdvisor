//+------------------------------------------------------------------+
//|                                            TEMA_Crossover_EA.mq5 |
//|                      Copyright 2025, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.01"

#include <Trade/Trade.mqh>

//--- input parameters
input int                FastTEMAPeriod = 57;      // Fast TEMA Period
input int                SlowTEMAPeriod = 36;      // Slow TEMA Period
input int                TrendMAPeriod = 6;      // Trend MA Period
input ENUM_APPLIED_PRICE AppliedPrice = PRICE_CLOSE; // Applied Price
input double             LotSize = 0.01;         // Lot Size
input int                StopLossPips = 150;      // Stop Loss in Pips
input int                TakeProfitPips = 150;   // Take Profit in Pips
input int                MagicNumber = 556677;   // Magic Number

//--- global variables
CTrade  trade;
int     fast_tema_handle;
int     slow_tema_handle;
int     trend_ma_handle;
double  fast_tema_buffer[3];
double  slow_tema_buffer[3];
double  trend_ma_buffer[2];

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- create trade instance
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetMarginMode();

//--- get indicator handles
   fast_tema_handle = iTEMA(_Symbol, _Period, FastTEMAPeriod, 0, AppliedPrice);
   slow_tema_handle = iTEMA(_Symbol, _Period, SlowTEMAPeriod, 0, AppliedPrice);
   trend_ma_handle = iMA(_Symbol, _Period, TrendMAPeriod, 0, MODE_SMA, PRICE_CLOSE);

   if(fast_tema_handle == INVALID_HANDLE || slow_tema_handle == INVALID_HANDLE || trend_ma_handle == INVALID_HANDLE)
     {
      printf("Error creating indicators");
      return(INIT_FAILED);
     }

//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- release indicator handles
   IndicatorRelease(fast_tema_handle);
   IndicatorRelease(slow_tema_handle);
   IndicatorRelease(trend_ma_handle);
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//--- use a static variable for bar count to ensure logic runs once per bar
   static int bars = 0;
   if(bars == Bars(_Symbol, _Period))
     {
      return; // Not a new bar, do nothing
     }
   bars = Bars(_Symbol, _Period);

//--- get indicator values. We copy 3 bars starting from the current one (bar 0)
//--- to ensure the indicator has time to calculate the values for the completed bars.
   if(CopyBuffer(fast_tema_handle, 0, 0, 3, fast_tema_buffer) != 3 ||
      CopyBuffer(slow_tema_handle, 0, 0, 3, slow_tema_buffer) != 3 ||
      CopyBuffer(trend_ma_handle, 0, 0, 2, trend_ma_buffer) != 2)
     {
      printf("Error copying indicator buffers");
      return;
     }

//--- check if a trade is already open for this symbol and magic number
   bool is_trade_open = false;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
        {
         is_trade_open = true;
         break;
        }
     }

//--- get the close price of the last completed bar (bar 1)
   MqlRates rates[1];
   if(CopyRates(_Symbol, _Period, 1, 1, rates) != 1)
     {
      printf("Error copying rates");
      return;
     }
   double close_price = rates[0].close;

//--- Trading logic
// buffer[2] = value on the bar before the signal bar (bar 2)
// buffer[1] = value on the signal bar (most recently completed, bar 1)
// buffer[0] = value on the current, incomplete bar (bar 0)

//--- check for buy signal (Fast TEMA crosses above Slow TEMA on the bar that just closed)
   if(fast_tema_buffer[2] <= slow_tema_buffer[2] && fast_tema_buffer[1] > slow_tema_buffer[1] && close_price > trend_ma_buffer[1])
     {
      if(!is_trade_open)
        {
         double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double sl = price - StopLossPips * _Point;
         double tp = price + TakeProfitPips * _Point;
         if(StopLossPips == 0) sl = 0;
         if(TakeProfitPips == 0) tp = 0;
         trade.Buy(LotSize, _Symbol, price, sl, tp, "TEMA Crossover Buy");
        }
     }

//--- check for sell signal (Fast TEMA crosses below Slow TEMA on the bar that just closed)
   if(fast_tema_buffer[2] >= slow_tema_buffer[2] && fast_tema_buffer[1] < slow_tema_buffer[1] && close_price < trend_ma_buffer[1])
     {
      if(!is_trade_open)
        {
         double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double sl = price + StopLossPips * _Point;
         double tp = price - TakeProfitPips * _Point;
         if(StopLossPips == 0) sl = 0;
         if(TakeProfitPips == 0) tp = 0;
         trade.Sell(LotSize, _Symbol, price, sl, tp, "TEMA Crossover Sell");
        }
     }
  }
//+------------------------------------------------------------------+
