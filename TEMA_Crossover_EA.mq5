//+------------------------------------------------------------------+
//|                                            TEMA_Crossover_EA.mq5 |
//|                      Copyright 2025, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade/Trade.mqh>

//--- input parameters
input int                FastTEMAPeriod = 57;      // Fast TEMA Period
input int                SlowTEMAPeriod = 36;      // Slow TEMA Period
input int                ADXPeriod = 14;         // ADX Period
input int                ADXThreshold = 25;      // ADX Trend Threshold
input ENUM_APPLIED_PRICE AppliedPrice = PRICE_CLOSE; // Applied Price
input double             LotSize = 0.01;         // Lot Size
input int                StopLossPips = 150;      // Stop Loss in Pips
input int                TakeProfitPips = 150;   // Take Profit in Pips
input int                MagicNumber = 556677;   // Magic Number

//--- global variables
CTrade  trade;
int     fast_tema_handle;
int     slow_tema_handle;
int     adx_handle;
double  fast_tema_buffer[2];
double  slow_tema_buffer[2];
double  adx_buffer[1];

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
   adx_handle = iADX(_Symbol, _Period, ADXPeriod);

   if(fast_tema_handle == INVALID_HANDLE || slow_tema_handle == INVALID_HANDLE || adx_handle == INVALID_HANDLE)
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
   IndicatorRelease(adx_handle);
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//--- static variable to store the bar time. This ensures the logic runs only once per bar.
   static datetime last_bar_time = 0;
   datetime current_bar_time = (datetime)SeriesInfoInteger(_Symbol, _Period, SERIES_LASTBAR_DATE);

   if(current_bar_time == last_bar_time)
     {
      return; // Not a new bar, do nothing
     }
   last_bar_time = current_bar_time;

//--- get indicator values for the last completed bar
   if(CopyBuffer(fast_tema_handle, 0, 1, 2, fast_tema_buffer) != 2 ||
      CopyBuffer(slow_tema_handle, 0, 1, 2, slow_tema_buffer) != 2 ||
      CopyBuffer(adx_handle, 0, 1, 1, adx_buffer) != 1) // 0 is the main ADX line
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

//--- get the close price of the last completed bar
   MqlRates rates[1];
   if(CopyRates(_Symbol, _Period, 1, 1, rates) != 1)
     {
      printf("Error copying rates");
      return;
     }
   double close_price = rates[0].close;

//--- Trading logic
// buffer[1] = value on the bar before the most recently completed bar
// buffer[0] = value on the most recently completed bar

//--- Trend condition: ADX must be above the threshold
   bool is_trending = adx_buffer[0] > ADXThreshold;

//--- check for buy signal (Fast TEMA crosses above Slow TEMA, and ADX is above threshold)
   if(fast_tema_buffer[1] <= slow_tema_buffer[1] && fast_tema_buffer[0] > slow_tema_buffer[0] && is_trending)
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

//--- check for sell signal (Fast TEMA crosses below Slow TEMA, and ADX is above threshold)
   if(fast_tema_buffer[1] >= slow_tema_buffer[1] && fast_tema_buffer[0] < slow_tema_buffer[0] && is_trending)
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
