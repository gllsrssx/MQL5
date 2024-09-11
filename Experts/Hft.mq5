#include <Trade\Trade.mqh>
CTrade trade;

double lotStep = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
MqlTick tick;

input double Lots = 0.01;
input double MaxSpread=1;

int OnInit()
{
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
}

bool IsMarketSuitable()
{
   double spread = (tick.ask-tick.bid) / Point();
   return (spread < MaxSpread);
}

void CloseAllTrades(){
   for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
      ulong ticket = PositionGetTicket(i);
      if (!PositionSelectByTicket(ticket))
        continue;
     
      trade.PositionClose(ticket);
    }
}

void CloseTradesInProfit(){
   for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
      ulong ticket = PositionGetTicket(i);
      if (!PositionSelectByTicket(ticket))
        continue;
      double profit = PositionGetDouble(POSITION_PROFIT);
      if(profit <= 0)continue;
      trade.PositionClose(ticket);
    }
}

void OnTick()
{
   SymbolInfoTick(Symbol(), tick);
   if (!IsMarketSuitable()){
      CloseAllTrades();
      return;
   }
   
   double ma_fast = iMA(Symbol(), 0, 5, 0, MODE_SMA, PRICE_CLOSE);
   double ma_slow = iMA(Symbol(), 0, 20, 0, MODE_SMA, PRICE_CLOSE);
   
   if (ma_fast > ma_slow){
      trade.Buy(Lots);
   }
   if (ma_fast < ma_slow){
      trade.Sell(Lots);
   }
   
   CloseTradesInProfit();
}