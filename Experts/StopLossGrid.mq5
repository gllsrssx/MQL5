#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"

#include <Trade/Trade.mqh>
#include <Arrays/ArrayLong.mqh>
#include <Arrays/ArrayObj.mqh>

class CSymbol : public CObject
{
public:
   CSymbol(string name) : symbol(name) {};
   ~CSymbol() {};

   string symbol;
   CArrayLong tickets;
   int handleAtr;
   double distance;
   double level;
   int direction;
   int retrace;
   double lots;
};

enum ENUM_SYMBOLS
{
   SYMBOLS_ALL,
   SYMBOLS_MAJOR,
   SYMBOLS_EURUSD,
   SYMBOLS_AUDUSD,
   SYMBOLS_GBPUSD,
   SYMBOLS_USDCAD,
   SYMBOLS_USDCHF,
   SYMBOLS_USDJPY,
   SYMBOLS_MINOR,
};
input ENUM_SYMBOLS SymbolsInput = SYMBOLS_ALL;
enum ENUM_RISK_VALUE
{
   RISK_VALUE_LOT,
   RISK_VALUE_PERCENT
};
input ENUM_RISK_VALUE RiskValue = RISK_VALUE_PERCENT;
enum ENUM_RISK_TYPE
{
   RISK_TYPE_BALANCE,
   RISK_TYPE_EQUITY,
   RISK_TYPE_STATIC
};
input ENUM_RISK_TYPE RiskType = RISK_TYPE_BALANCE;
input double RiskValueAmount = 1.0;

input ENUM_TIMEFRAMES AtrTimeframe = PERIOD_M15;
input int AtrPeriods = 14;
input int AtrDeclinePeriod = 4;

input int Magic = 8;
input int StartTradingHour = 2;
input int StopTradingHour = 20;
input int maxSpread = 20;
input bool Martingale = false;

CArrayObj symbols;
//int barsTotal;
double arrMartin[] = {1,1,2.5,5,10,20,40,80,160,320,0};
int maxRetrace=0;

int OnInit()
{
   string arrSymbols[];
   if (SymbolsInput == SYMBOLS_MAJOR)
   {
      ArrayResize(arrSymbols, 6);
      arrSymbols[0] = "EURUSD";
      arrSymbols[1] = "USDJPY";
      arrSymbols[2] = "GBPUSD";
      arrSymbols[3] = "AUDUSD";
      arrSymbols[4] = "USDCAD";
      arrSymbols[5] = "USDCHF";
   }
   else if (SymbolsInput == SYMBOLS_MINOR)
   {
      ArrayResize(arrSymbols, 20);
      arrSymbols[0] = "AUDCHF";
      arrSymbols[1] = "AUDJPY";
      arrSymbols[2] = "AUDNZD";
      arrSymbols[3] = "CADCHF";
      arrSymbols[4] = "CADJPY";
      arrSymbols[5] = "CHFJPY";
      arrSymbols[6] = "EURAUD";
      arrSymbols[7] = "EURCAD";
      arrSymbols[8] = "EURCHF";
      arrSymbols[9] = "EURGBP";
      arrSymbols[10] = "AUDCAD";
      arrSymbols[11] = "EURJPY";
      arrSymbols[12] = "USDSGD";
      arrSymbols[13] = "EURNZD";
      arrSymbols[14] = "GBPAUD";
      arrSymbols[15] = "GBPCAD";
      arrSymbols[16] = "GBPCHF";
      arrSymbols[17] = "GBPJPY";
      arrSymbols[18] = "GBPNZD";
      arrSymbols[19] = "NZDCAD";
   }
   else if (SymbolsInput == SYMBOLS_ALL)
   {
      ArrayResize(arrSymbols, 26);
      arrSymbols[0] = "EURUSD";
      arrSymbols[1] = "USDJPY";
      arrSymbols[2] = "GBPUSD";
      arrSymbols[3] = "AUDUSD";
      arrSymbols[4] = "USDCAD";
      arrSymbols[5] = "USDCHF";
      arrSymbols[6] = "AUDCHF";
      arrSymbols[7] = "AUDJPY";
      arrSymbols[8] = "AUDNZD";
      arrSymbols[9] = "CADCHF";
      arrSymbols[10] = "CADJPY";
      arrSymbols[11] = "CHFJPY";
      arrSymbols[12] = "EURAUD";
      arrSymbols[13] = "EURCAD";
      arrSymbols[14] = "EURCHF";
      arrSymbols[15] = "EURGBP";
      arrSymbols[16] = "AUDCAD";
      arrSymbols[17] = "EURJPY";
      arrSymbols[18] = "USDSGD";
      arrSymbols[19] = "EURNZD";
      arrSymbols[20] = "GBPAUD";
      arrSymbols[21] = "GBPCAD";
      arrSymbols[22] = "GBPCHF";
      arrSymbols[23] = "GBPJPY";
      arrSymbols[24] = "GBPNZD";
      arrSymbols[25] = "NZDCAD";
   }
   else if (SymbolsInput == SYMBOLS_EURUSD)
   {
      ArrayResize(arrSymbols, 1);
      arrSymbols[0] = "EURUSD";
   }
   else if (SymbolsInput == SYMBOLS_USDJPY)
   {
      ArrayResize(arrSymbols, 1);
      arrSymbols[0] = "USDJPY";
   }
   else if (SymbolsInput == SYMBOLS_GBPUSD)
   {
      ArrayResize(arrSymbols, 1);
      arrSymbols[0] = "GBPUSD";
   }
   else if (SymbolsInput == SYMBOLS_AUDUSD)
   {
      ArrayResize(arrSymbols, 1);
      arrSymbols[0] = "AUDUSD";
   }
   else if (SymbolsInput == SYMBOLS_USDCAD)
   {
      ArrayResize(arrSymbols, 1);
      arrSymbols[0] = "USDCAD";
   }
   else if (SymbolsInput == SYMBOLS_USDCHF)
   {
      ArrayResize(arrSymbols, 1);
      arrSymbols[0] = "USDCHF";
   }

   symbols.Clear();
   for (int i = ArraySize(arrSymbols) - 1; i >= 0; i--)
   {
      CSymbol *symbol = new CSymbol(arrSymbols[i]);
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

   // int bars = iBars(_Symbol, AtrTimeframe);
   // if (barsTotal != bars)
   // {
   //    barsTotal = bars;

   for (int j = symbols.Total() - 1; j >= 0; j--)
   {
      CSymbol *symbol = symbols.At(j);

      CTrade trade;
      trade.SetExpertMagicNumber(Magic);

      int posC = PositionsCount(symbol.symbol);
      double last = (SymbolInfoDouble(symbol.symbol, SYMBOL_ASK) + SymbolInfoDouble(symbol.symbol, SYMBOL_BID)) / 2;

      for (int i = symbol.tickets.Total() - 1; i >= 0; i--)
      {
         if(posC==0)break;
         double levelAbove = symbol.level + symbol.distance;
         double levelBelow = symbol.level - symbol.distance;

         bool gridSignal = ((symbol.direction == 1 && last >= levelAbove) ||
                            (symbol.direction == -1 && last <= levelBelow) ||
                            (symbol.direction == 0 && last >= levelAbove) ||
                            (symbol.direction == 0 && last <= levelBelow));
         if (gridSignal)
         {
            symbol.direction = symbol.direction == 0 && last >= levelAbove ? 1 : 
                               symbol.direction == 0 && last <= levelBelow ? -1 : 
                               symbol.direction;
            symbol.level = last;
            double lots = symbol.lots;
            double adjustedLots = lots * arrMartin[symbol.retrace];
            double lotStep = SymbolInfoDouble(symbol.symbol, SYMBOL_VOLUME_STEP);
            double minVol = SymbolInfoDouble(symbol.symbol, SYMBOL_VOLUME_MIN);
            double maxVol = SymbolInfoDouble(symbol.symbol, SYMBOL_VOLUME_MAX);
            
            adjustedLots = MathRound(adjustedLots / lotStep) * lotStep;
            if (adjustedLots < minVol)
               adjustedLots = minVol;
            else if (adjustedLots > maxVol)
               adjustedLots = maxVol;

            trade.Sell(Martingale && symbol.direction == 1 ? adjustedLots: lots, symbol.symbol, 0, 0, symbol.level - symbol.distance);
            if (trade.ResultOrder() > 0 && trade.ResultRetcode() == TRADE_RETCODE_DONE)
            {
               Print(__FUNCTION__, " > Ticket added for ", symbol.symbol, "...");
               symbol.tickets.Add(trade.ResultOrder());
            }
            trade.Buy(Martingale && symbol.direction == -1 ? adjustedLots: lots, symbol.symbol, 0, 0, symbol.level + symbol.distance); 
            if (trade.ResultOrder() > 0 && trade.ResultRetcode() == TRADE_RETCODE_DONE)
            {
               Print(__FUNCTION__, " > Ticket added for ", symbol.symbol, "...");
               symbol.tickets.Add(trade.ResultOrder());
            }
            if(Martingale)Print(__FUNCTION__, " > retrace level ", symbol.retrace, " > martin multiplier ", arrMartin[symbol.retrace]);

            for (int k = symbol.tickets.Total() - 1; k >= 0; k--)
            {
               CPositionInfo pos;
               if (pos.SelectByTicket(symbol.tickets.At(k)))
               {
                     int digits = (int)SymbolInfoInteger(symbol.symbol,SYMBOL_DIGITS);
                     if (pos.PositionType() == POSITION_TYPE_BUY)
                     {
                        double takeProfit = NormalizeDouble(symbol.level + symbol.distance,digits);
                        double stopLoss = NormalizeDouble(symbol.direction == 1? symbol.level - symbol.distance: 0,digits);
                        
                        if(pos.TakeProfit() == takeProfit && pos.StopLoss() == stopLoss)continue;
                        trade.PositionModify(pos.Ticket(), stopLoss, takeProfit);
                     }
                     else if (pos.PositionType() == POSITION_TYPE_SELL)
                     {
                     
                        double takeProfit = NormalizeDouble(symbol.level - symbol.distance,digits);
                        double stopLoss = NormalizeDouble(symbol.direction == -1? symbol.level + symbol.distance: 0,digits);
                        if(pos.TakeProfit() == takeProfit && pos.StopLoss() == stopLoss)continue;
                        trade.PositionModify(pos.Ticket(), stopLoss, takeProfit);
                     }
               }
            }
            symbol.retrace++;if(symbol.retrace>maxRetrace)maxRetrace=symbol.retrace;
         }
      }
      
      double atr[];
      CopyBuffer(symbol.handleAtr, MAIN_LINE, 1, AtrDeclinePeriod+1, atr);
      bool isAtrSignal = true;
      for (int i = 0; i < AtrDeclinePeriod; i++)
      {
         if (atr[i] <= atr[i + 1])
         {
            isAtrSignal = false;
            break;
         }
      }
      
      if (posC == 0 && isAtrSignal && (StartTradingHour==0||dt.hour > StartTradingHour) && (StopTradingHour==0|| dt.hour < StopTradingHour) && maxSpread > SymbolInfoInteger(symbol.symbol, SYMBOL_SPREAD))
      {
         symbol.distance = atr[0];
         symbol.level = last;
         symbol.direction = 0;
         symbol.retrace = 0;
         symbol.lots = Volume(symbol.symbol, symbol.distance);
         
         Print(__FUNCTION__, " > First signal for ", symbol.symbol, "...");
         trade.Sell(symbol.lots, symbol.symbol, 0, 0, last - atr[0]);
         if (trade.ResultOrder() > 0 && trade.ResultRetcode() == TRADE_RETCODE_DONE)
         {
            Print(__FUNCTION__, " > Ticket added for ", symbol.symbol, "...");
            symbol.tickets.Add(trade.ResultOrder());
         }
         trade.Buy(symbol.lots, symbol.symbol, 0, 0, last + atr[0]);
         if (trade.ResultOrder() > 0 && trade.ResultRetcode() == TRADE_RETCODE_DONE)
         {
            Print(__FUNCTION__, " > Ticket added for ", symbol.symbol, "...");
            symbol.tickets.Add(trade.ResultOrder());
         }
      }
   }
}

int PositionsCount(string sym){
   int count=0;
   for (int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if (PositionSelectByTicket(ticket) && PositionGetString(POSITION_SYMBOL) == sym && PositionGetInteger(POSITION_MAGIC) == Magic)
      {
         count++;
      }
   }
   return count;
}

double capital = AccountInfoDouble(ACCOUNT_BALANCE);
double Volume(string symbolName, double distance)
{
   if (RiskValue == RISK_VALUE_LOT)
      return RiskValueAmount;

   if (RiskType == RISK_TYPE_BALANCE)
      capital = AccountInfoDouble(ACCOUNT_BALANCE);
   else if (RiskType == RISK_TYPE_EQUITY)
      capital = AccountInfoDouble(ACCOUNT_EQUITY);

   double tickSize = SymbolInfoDouble(symbolName, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(symbolName, SYMBOL_TRADE_TICK_VALUE);
   double lotStep = SymbolInfoDouble(symbolName, SYMBOL_VOLUME_STEP);

   double riskMoney = capital * RiskValueAmount / 100;
   double moneyLotStep = distance / tickSize * tickValue * lotStep;

   double lots = MathFloor(riskMoney / moneyLotStep) * lotStep;

   double minVol = SymbolInfoDouble(symbolName, SYMBOL_VOLUME_MIN);
   double maxVol = SymbolInfoDouble(symbolName, SYMBOL_VOLUME_MAX);

   if (lots < minVol)
      return minVol;

   else if (lots > maxVol)
      return maxVol;

   return lots;
}
