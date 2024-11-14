#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"

#include <Trade/Trade.mqh>
#include <Arrays/ArrayLong.mqh>
#include <Arrays/ArrayObj.mqh>

class CSymbol : public CObject {
public:
      CSymbol(string name) : symbol(name) {};
      ~CSymbol() {};

   string symbol;
   CArrayLong tickets;
   int handleAtr;
};

input double Lots = 0.01;
input int IncreaseAfterX = 5;
input int DaysBack = 30;
input double TriggerPercent = 8.0;
input double StepPercent = 2.0;
input double ProfitLotStep = 10;
input int AtrPeriods = 14;
input ENUM_TIMEFRAMES AtrTimeframe = PERIOD_H1;
input int AtrDeclinePeriod = 5;

CArrayObj symbols;
int barsTotal;

int OnInit()
{
   string arrSymbols[] = {
       // majors
       "EURUSD",
       "USDJPY",
       "GBPUSD",
       "AUDUSD",
       "USDCAD",
       "USDCHF",
       // minors
       "AUDCHF",
       "AUDJPY",
       "AUDNZD",
       "CADCHF",
       "CADJPY",
       "CHFJPY",
       "EURAUD",
       "EURCAD",
       "EURCHF",
       "EURGBP",
       "AUDCAD",
       "EURJPY",
       "USDSGD",
       "EURNZD",
       "GBPAUD",
       "GBPCAD",
       "GBPCHF",
       "GBPJPY",
       "GBPNZD",
       "NZDCAD",
       "NZDCHF",
       "NZDJPY",
       "NZDUSD"
   };

   symbols.Clear();
   for(int i = ArraySize(arrSymbols) - 1; i >= 0; i--) {
      CSymbol* symbol = new CSymbol(arrSymbols[i]);
      symbol.handleAtr = iATR(symbol.symbol, AtrTimeframe, AtrPeriods);
      symbols.Add(symbol);
   }

   return (INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
}

void OnTick()
{
   MqlDateTime dt;
   TimeCurrent(dt);

   int bars = iBars(_Symbol, AtrTimeframe);
   if (barsTotal != bars && dt.hour > 10){
      barsTotal = bars;
      
      for(int j = symbols.Total()-1; j >= 0; j--){
         CSymbol* symbol = symbols.At(j);

         CTrade trade;

         double bid = SymbolInfoDouble(symbol.symbol, SYMBOL_BID);
         
         double atr[];
         CopyBuffer(symbol.handleAtr, MAIN_LINE, 1, AtrDeclinePeriod, atr);
         bool isAtrSignal = atr[AtrDeclinePeriod - 1] < atr[0];

         double profit = 0;
         double lots = 0;
         for (int i = symbol.tickets.Total() - 1; i >= 0; i--)
         {
            CPositionInfo pos;
            if (pos.SelectByTicket(symbol.tickets.At(i)))
            {
               profit += pos.Profit() + pos.Swap();
               lots += pos.Volume();

               if (i == symbol.tickets.Total() - 1 && isAtrSignal)
               {
                  if (pos.PositionType() == POSITION_TYPE_BUY && bid < pos.PriceOpen() - pos.PriceOpen() * StepPercent / 100)
                  {
                     Print(__FUNCTION__, " > Step buy signal for ", symbol.symbol, "...");

                     double lots = Lots;
                     if (symbol.tickets.Total() >= IncreaseAfterX)
                        lots += Lots * (symbol.tickets.Total() - IncreaseAfterX + 1);

                     trade.Buy(lots, symbol.symbol);
                  }
                  else if (pos.PositionType() == POSITION_TYPE_SELL && bid > pos.PriceOpen() + pos.PriceOpen() * StepPercent / 100)
                  {
                     Print(__FUNCTION__, " > Step sell signal for ", symbol.symbol, "...");

                     double lots = Lots;
                     if (symbol.tickets.Total() >= IncreaseAfterX)
                        lots += Lots * (symbol.tickets.Total() - IncreaseAfterX + 1);

                     trade.Sell(lots, symbol.symbol);
                  }
               }
            }
         }

         if (symbol.tickets.Total() == 0 && isAtrSignal)
         {
            double openBack = iOpen(symbol.symbol, PERIOD_D1, DaysBack);

            if (MathAbs(openBack - bid) / openBack > TriggerPercent / 100)
            {
               if (openBack < bid)
               {
                  Print(__FUNCTION__, " > First sell signal for ", symbol.symbol, "...");
                  trade.Sell(Lots, symbol.symbol);
               }
               else
               {
                  Print(__FUNCTION__, " > First Buy signal for ", symbol.symbol, "...");
                  trade.Buy(Lots, symbol.symbol);
               }
            }
         }

         if (trade.ResultOrder() > 0 && trade.ResultRetcode() == TRADE_RETCODE_DONE)
         {
            Print(__FUNCTION__, " > Ticket added for ", symbol.symbol, "...");
            symbol.tickets.Add(trade.ResultOrder());
         }

         if (profit > ProfitLotStep * symbol.tickets.Total())
         {
            Print(__FUNCTION__, " > Hit profit for ", symbol.symbol, "...");
            for (int i = symbol.tickets.Total() - 1; i >= 0; i--)
            {
               CPositionInfo pos;
               if (pos.SelectByTicket(symbol.tickets.At(i)))
               {
                  if (trade.PositionClose(pos.Ticket()))
                  {
                     symbol.tickets.Delete(i);
                  }
               }
            }
         }
      }
   }
}
