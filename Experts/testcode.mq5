//+------------------------------------------------------------------+
//|                                                     MyExpert.mq5 |
//|                        Copyright 2023, MetaQuotes Software Corp. |
//|                                       http://www.metaquotes.net/ |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>
CTrade trade;

input int movingAveragePeriod = 50;
input double sarStep = 0.02;
input double sarMaximum = 0.2;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
  // Initialization code here
  return (INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
  // Deinitialization code here
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
  // Calculate the 50-period SMA
  double ma = iMA(NULL, PERIOD_CURRENT, 0, movingAveragePeriod, 0, MODE_SMA, PRICE_CLOSE, 0);
  // Get the current price
  double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
  // Calculate Parabolic SAR
  double sar = iSAR(NULL, PERIOD_CURRENT, 0, sarStep, sarMaximum, 0);

  // Conditions to open a long position
  if (price > ma && price > sar && !PositionSelect(_Symbol))
  {
    trade.Buy(0.1, _Symbol); // Adjust the volume according to your risk management
  }

  // Conditions to close a long position
  if (price < ma && PositionSelect(_Symbol))
  {
    trade.Close(_Symbol);
  }
}
//+------------------------------------------------------------------+