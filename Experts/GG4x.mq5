#property description "grid trading ea"
#property copyright "Copyright 2023, Gilles Rousseaux."
#property link      "https://github.com/G1-R0"
#property version   "1.00"
#property strict
#define EXPERT_MAGIC 20393                             // MagicNumber of the expert

#include <..\Include\Trade\Trade.mqh>
#include <..\Include\Trade\SymbolInfo.mqh>

int OnInit()
  {
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
  }

input double LotSize = 0.1;
input int GridSize = 50;

double maxDDc = 0;
double maxDD = 0;
double currDD = 0;
double equity = 0;
double balance = 0;

double ask = 0;
double bid =0;

double GridLevelAbove = 0;
double GridLevelBelow = 0;

double lastGridLevelAbove = 0;
double lastGridLevelBelow = 999999999;

int longCount = 0;
int shortCount = 0;

int decimalPlaces = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

void OnTick(){
   equity = AccountInfoDouble(ACCOUNT_EQUITY);
   balance = AccountInfoDouble(ACCOUNT_BALANCE);
   currDD = MyCeil(((balance-equity)/balance) * 100);
   maxDD = MyCeil(MathMax(maxDD, currDD));
   maxDDc = MyCeil(MathMax(maxDDc, balance-equity));   

   Comment("Balance: ", balance, "\nEquity: ", equity, "\nCurrent Drawdown: ", currDD, "\nMax Drawdown: ", maxDD, "\nMax DD Cash: ", maxDDc);
   
   ask = NormalizeDouble(SymbolInfoDouble(_Symbol,SYMBOL_ASK), decimalPlaces);
   bid = NormalizeDouble(SymbolInfoDouble(_Symbol,SYMBOL_BID), decimalPlaces);

   while(GridLevelAbove < ask){
      GridLevelAbove += GridSize * _Point;
   }     
   GridLevelBelow = GridLevelAbove - GridSize * _Point;
   
   GridLevelAbove = NormalizeDouble(GridLevelAbove, decimalPlaces);
   GridLevelBelow = NormalizeDouble(GridLevelBelow, decimalPlaces);

   if (GridLevelBelow >= lastGridLevelAbove){
      longCount ++;
      shortCount = 0;
      lastGridLevelAbove = GridLevelAbove;
   }
   if (GridLevelAbove <= lastGridLevelBelow){
      shortCount ++;
      longCount = 0;
      lastGridLevelBelow = GridLevelBelow;
   }
     
   CheckAndCreate(GridLevelAbove);
   CheckAndCreate(GridLevelBelow); 
Print("GridLevelAbove: ", GridLevelAbove," lastGridLevelAbove: ",lastGridLevelAbove," longCount: ",longCount);

Print("GridLevelBelow: ",GridLevelBelow," lastGridLevelBelow: ",lastGridLevelBelow," shortCount: ",shortCount);
}

double MyCeil(double value){
   return (MathCeil(value/0.01)*0.01);
}

void CheckAndCreate(double price){

   double buyTakeProfit = price + GridSize * _Point;
   double sellTakeProfit = price - GridSize * _Point;
   
   if(!check(_Symbol, buyTakeProfit, "Long")){ 
      if (shortCount <= 30){   
         create(price, buyTakeProfit, "Long");
      }
   }
   if(!check(_Symbol, sellTakeProfit, "Short")){    
      if (longCount <= 30){
         create(price, sellTakeProfit, "Short");
      }
   }
}
bool check(string symbol, double tp, string direction){
// Check pending orders
   for(int i = OrdersTotal() - 1; i >= 0; i--){
      ulong orderTicket = OrderGetTicket(i);
      if(OrderSelect(orderTicket)){
         string orderSymbol = OrderGetString(ORDER_SYMBOL);
         double orderTakeProfit = OrderGetDouble(ORDER_TP);
         string orderComment = OrderGetString(ORDER_COMMENT);
         if(orderSymbol == symbol && MathAbs(orderTakeProfit - tp) < _Point && orderComment == direction){
            return true;
         }
      }
   }
// Check open positions
   for(int i = PositionsTotal() - 1; i >= 0; i--){
      ulong posTicket = PositionGetTicket(i);
      if(PositionSelectByTicket(posTicket)){
         string posSymbol = PositionGetString(POSITION_SYMBOL);
         double posTakeProfit = PositionGetDouble(POSITION_TP);
         string posComment = PositionGetString(POSITION_COMMENT);
         if(posSymbol == symbol && MathAbs(posTakeProfit - tp) < _Point && posComment == direction){
            return true;
         }
      }
   }
   return false;
}

void create(double price, double takeProfit, string comment) {
   MqlTradeRequest request = {};
   MqlTradeResult  result = {};
   request.symbol    = _Symbol;
   request.action    = TRADE_ACTION_PENDING;
   request.volume    = LotSize;
   request.price     = price;
   request.stoplimit = price;
   request.sl        = 0;      
   request.tp        = takeProfit;
   request.type_time = ORDER_TIME_DAY;
   request.magic     = EXPERT_MAGIC;
   request.comment   = comment;
      
   if (comment == "Long"){
      if (ask > price){
         request.type      = ORDER_TYPE_BUY_LIMIT;
      }
      else{
         request.type      = ORDER_TYPE_BUY_STOP_LIMIT;
      }
   }
   else{
      if (bid < price){
         request.type      = ORDER_TYPE_SELL_LIMIT;
      }
      else{
         request.type      = ORDER_TYPE_SELL_STOP_LIMIT;
      }
   }
   if(!OrderSend(request, result)){
      PrintFormat("OrderSend error %d",GetLastError());
      PrintFormat("retcode=%u  deal=%I64u  order=%I64u",result.retcode,result.deal,result.order);
   }
}

   