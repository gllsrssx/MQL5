// Grid Trading Expert Advisor: This EA uses a grid trading strategy to execute trades. It places trades at regular intervals, 
// defined by the GridSize parameter. The EA places a new trade when the price moves a distance of GridSize from the previous trade. 
// The maximum number of simultaneous trades in the opposite direction during the trend is set by MaxTrades parameter.

#property description "Grid Trading EA"
#property copyright "Copyright 2023, Gilles Rousseaux."
#property link "https://github.com/G1-R0"
#property version "1.00"
#property strict

// MagicNumber of the expert
#define EXPERT_MAGIC 20393

// MQL5 includes
#include <Trade\Trade.mqh>

// Create instance of CTrade
CTrade trade;

// Input parameters for the script.
input double LotSize = 0.1;   // Lot size for each trade.
input int GridSize = 50;      // Distance between grid levels.
input int MaxTrades = 10;      // Maximum number of trades in opposite direction during a trend.

// Variables to store current ask and bid prices, grid levels and the number of long and short trades.
double ask = 0, bid = 0, GridLevelAbove = 0, GridLevelBelow = 999999999;
int LongTradeCount = 0, ShortTradeCount = 0;
int longCount = 0, shortCount = 0;

// Variable to store the current trending direction. Can be "Long", "Short", or "" (for no trend).
string trendingDirection = "";

// decimals for the math round of levels
int decimalPlaces = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

// vars for stats
double balance = 0, equity = 0, currentDD = 0, maxDD = 0, cashDD = 0;

// Function called when the EA is initialized
int OnInit(){
   return(INIT_SUCCEEDED);
}

// Function called when the EA is deinitialized
void OnDeinit(const int reason){}

// Function called on every new tick of the market
void OnTick(){
   // update stats
   UpdateStats();
   
   // ask bid and gridlevels
   UpdateLevels();

   //trading
   manageTrades();
}
 void UpdateStats(){
   balance = AccountInfoDouble(ACCOUNT_BALANCE);
   equity = AccountInfoDouble(ACCOUNT_EQUITY);
   currentDD = myCeil(((balance-equity)/balance) * 100);
   maxDD = myCeil(MathMax(maxDD, currentDD));
   cashDD = myCeil(MathMax(cashDD, balance-equity));
   Comment("Balance: ", balance, "\nEquity: ", equity, "\nCurrent Drawdown: ", currentDD, "\nMax Drawdown: ", maxDD, "\nCash max DD: ", cashDD);
 }
void UpdateLevels(){
   ask = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), decimalPlaces);
   bid = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID), decimalPlaces);
   
      while(GridLevelAbove < ask){
      GridLevelAbove += GridSize * _Point;
   }     
   GridLevelBelow = GridLevelAbove - GridSize * _Point;
   
   GridLevelAbove = NormalizeDouble(GridLevelAbove, decimalPlaces);
   GridLevelBelow = NormalizeDouble(GridLevelBelow, decimalPlaces);
}
// Function to manage the creation and update of orders
void manageTrades(){
   ManageTradesLong(GridLevelAbove);
   ManageTradesLong(GridLevelBelow);
   
   ManageTradeShort(GridLevelAbove);
   ManageTradeShort(GridLevelBelow);

}

void ManageTradesLong(double price){
   double longProfit = NormalizeDouble((price + GridSize * _Point), decimalPlaces);
   if(!TradeExists(_Symbol, longProfit, "Long") ){   //&& shouldCreateOrder("Long")
      createOrder(price, longProfit, "Long");
   }
}
void ManageTradeShort(double price){
   double shortProfit = NormalizeDouble((price - GridSize * _Point), decimalPlaces);
   if(!TradeExists(_Symbol, shortProfit, "Short") ){   //&& shouldCreateOrder("Short")
      createOrder(price, shortProfit, "Short");
   }
}

// Function to check if a trade already exists
bool TradeExists(string symbol, double tp, string direction){
   for(int i = OrdersTotal() - 1; i >= 0; i--){
      ulong orderTicket = OrderGetTicket(i);
      if(OrderSelect(orderTicket)){
         if(orderMatches(symbol, tp, direction)){
            return true;
         }
      }
   }
   for(int i = PositionsTotal() - 1; i >= 0; i--){
      ulong posTicket = PositionGetTicket(i);
      if(PositionSelectByTicket(posTicket)){
         if(positionMatches(symbol, tp, direction)){
            return true;
         }
      }
   }
   return false;
}

// Function to match order parameters
bool orderMatches(string symbol, double tp, string direction){
   return (OrderGetString(ORDER_SYMBOL) == symbol && NormalizeDouble(OrderGetDouble(ORDER_TP), decimalPlaces) == NormalizeDouble(tp, decimalPlaces) && OrderGetString(ORDER_COMMENT) == direction);
}

// Function to match position parameters
bool positionMatches(string symbol, double tp, string direction){
   return (PositionGetString(POSITION_SYMBOL) == symbol && NormalizeDouble(PositionGetDouble(POSITION_TP), decimalPlaces) == NormalizeDouble(tp, decimalPlaces) && PositionGetString(POSITION_COMMENT) == direction);
}

// Function to decide if a new order should be created based on trending direction
bool shouldCreateOrder(string direction){
   if(trendingDirection == "") return true;
   if(trendingDirection == direction && (direction == "Long" ? longCount < MaxTrades : shortCount < MaxTrades)) return true;
   return false;
}

// Function to create a new order
void createOrder(double price, double takeProfit, string direction) {
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
   request.comment   = direction;

   if (direction == "Long"){
      request.type = ask > price ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_BUY_STOP;
   }
   else{
      request.type = bid < price ? ORDER_TYPE_SELL_LIMIT : ORDER_TYPE_SELL_STOP;
   }
   
   if(!OrderSend(request, result)){
      PrintFormat("OrderSend error %d",GetLastError());
      PrintFormat("retcode=%u  deal=%I64u  order=%I64u",result.retcode,result.deal,result.order);
   }

   updateTrendingDirection(direction);
}

// Function to update the trending direction
void updateTrendingDirection(string direction){
   if(direction == "Long") longCount++;
   else shortCount++;

   if(longCount > shortCount + MaxTrades) trendingDirection = "Long";
   else if(shortCount > longCount + MaxTrades) trendingDirection = "Short";
   else trendingDirection = "";
}

// Helper function to round a double value to the nearest cent
double myCeil(double value){
   return (MathCeil(value/0.01)*0.01);
}