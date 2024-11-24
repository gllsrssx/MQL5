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
   int handleEmaL;
   int handleEmaM;
   int handleEmaS;
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
input ENUM_SYMBOLS SymbolsInput = SYMBOLS_ALL; // Symbols
enum ENUM_RISK_VALUE
{
   RISK_VALUE_LOT,
   RISK_VALUE_PERCENT
};
input ENUM_RISK_VALUE RiskValue = RISK_VALUE_PERCENT; // Risk Value
enum ENUM_RISK_TYPE
{
   RISK_TYPE_BALANCE,
   RISK_TYPE_EQUITY,
   RISK_TYPE_STATIC
};
input ENUM_RISK_TYPE RiskType = RISK_TYPE_BALANCE; // Risk Type
input double RiskValueAmount = 1.0;                // Risk Amount

input ENUM_TIMEFRAMES InpTimeFrame = PERIOD_M15; // TimeFrame

input bool UseAtrSignal = true; // Atr Signal
input int AtrPeriods = 14;      // Atr Period
input int AtrDeclinePeriod = 4; // Atr Decline Period

input bool UseEmaSignal = true; // Ema Signal
input int emaShortPeriod = 7;   // Ema Short
input int emaMediumPeriod = 14; // Ema Medium
input int emaLongPeriod = 21;   // Ema Long
input ENUM_APPLIED_PRICE emaPrice = PRICE_CLOSE; // Ema Price

input int Magic = 8;            // Magic Number
input int StartTradingHour = 2; // Start Trading Hour
input int StopTradingHour = 20; // Stop Trading Hour
input int maxSpread = 20;       // Max Allowed Spread
input bool Martingale = false;  // Martingale

CArrayObj symbols;
// int barsTotal;
double arrMartin[] = {1, 1, 2.5, 5, 10, 20, 40, 80, 160, 320, 0};
int maxRetrace = 0;

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

   // int bars = iBars(_Symbol, InpTimeFrame);
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

      symbol.handleAtr = iATR(symbol.symbol, InpTimeFrame, AtrPeriods);
      double atr[];
      ArraySetAsSeries(atr, true);
      CopyBuffer(symbol.handleAtr, MAIN_LINE, 0, AtrDeclinePeriod + AtrPeriods + 1, atr);

      symbol.handleEmaL = iMA(symbol.symbol, InpTimeFrame, emaLongPeriod, 0, MODE_EMA, emaPrice);
      symbol.handleEmaM = iMA(symbol.symbol, InpTimeFrame, emaMediumPeriod, 0, MODE_EMA, PRICE_CLOSE);
      symbol.handleEmaS = iMA(symbol.symbol, InpTimeFrame, emaShortPeriod, 0, MODE_EMA, PRICE_CLOSE);
      double emaL[], emaM[], emaS[];
      ArraySetAsSeries(emaL, true);
      ArraySetAsSeries(emaM, true);
      ArraySetAsSeries(emaS, true);
      CopyBuffer(symbol.handleEmaS, 0, 0, emaShortPeriod+1, emaS);
      CopyBuffer(symbol.handleEmaM, 0, 0, emaMediumPeriod, emaM);
      CopyBuffer(symbol.handleEmaL, 0, 0, emaLongPeriod, emaL);

      for (int i = symbol.tickets.Total() - 1; i >= 0; i--)
      {
         if (posC == 0)
            break;
         double levelAbove = symbol.level + symbol.distance;
         double levelBelow = symbol.level - symbol.distance;

         bool gridSignal = ((symbol.direction == 1 && last >= levelAbove) ||
                            (symbol.direction == -1 && last <= levelBelow) ||
                            (symbol.direction == 0 && last >= levelAbove) ||
                            (symbol.direction == 0 && last <= levelBelow));
         if (gridSignal)
         {
            symbol.direction = symbol.direction == 0 && last >= levelAbove ? 1 : symbol.direction == 0 && last <= levelBelow ? -1
                                                                                                                             : symbol.direction;
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

            trade.Sell(Martingale && symbol.direction == 1 ? adjustedLots : lots, symbol.symbol, 0, 0, symbol.level - symbol.distance);
            if (trade.ResultOrder() > 0 && trade.ResultRetcode() == TRADE_RETCODE_DONE)
            {
               Print(__FUNCTION__, " > Ticket added for ", symbol.symbol, "...");
               symbol.tickets.Add(trade.ResultOrder());
            }
            trade.Buy(Martingale && symbol.direction == -1 ? adjustedLots : lots, symbol.symbol, 0, 0, symbol.level + symbol.distance);
            if (trade.ResultOrder() > 0 && trade.ResultRetcode() == TRADE_RETCODE_DONE)
            {
               Print(__FUNCTION__, " > Ticket added for ", symbol.symbol, "...");
               symbol.tickets.Add(trade.ResultOrder());
            }
            if (Martingale)
               Print(__FUNCTION__, " > retrace level ", symbol.retrace, " > martin multiplier ", arrMartin[symbol.retrace]);

            for (int k = symbol.tickets.Total() - 1; k >= 0; k--)
            {
               CPositionInfo pos;
               if (pos.SelectByTicket(symbol.tickets.At(k)))
               {
                  int digits = (int)SymbolInfoInteger(symbol.symbol, SYMBOL_DIGITS);
                  if (pos.PositionType() == POSITION_TYPE_BUY)
                  {
                     double takeProfit = NormalizeDouble(symbol.level + symbol.distance, digits);
                     double stopLoss = NormalizeDouble(symbol.direction == 1 ? symbol.level - symbol.distance : 0, digits);

                     if (pos.TakeProfit() == takeProfit && pos.StopLoss() == stopLoss)
                        continue;
                     trade.PositionModify(pos.Ticket(), stopLoss, takeProfit);
                  }
                  else if (pos.PositionType() == POSITION_TYPE_SELL)
                  {

                     double takeProfit = NormalizeDouble(symbol.level - symbol.distance, digits);
                     double stopLoss = NormalizeDouble(symbol.direction == -1 ? symbol.level + symbol.distance : 0, digits);
                     if (pos.TakeProfit() == takeProfit && pos.StopLoss() == stopLoss)
                        continue;
                     trade.PositionModify(pos.Ticket(), stopLoss, takeProfit);
                  }
               }
            }
            symbol.retrace++;
            if (symbol.retrace > maxRetrace)
               maxRetrace = symbol.retrace;
         }
      }

      bool isAtrSignal = true;
      for (int i = 0; i < AtrDeclinePeriod; i++)
      {
         if (atr[i] > atr[i + 1])
         {
            isAtrSignal = false;
            break;
         }
      }

      bool emaSignal = !((emaS[1] > emaM[1] && emaM[1] > emaL[1]) || (emaS[1] < emaM[1] && emaM[1] < emaL[1]));

      if (posC == 0 && (isAtrSignal || !UseAtrSignal) && (emaSignal || !UseEmaSignal) && (StartTradingHour == 0 || dt.hour > StartTradingHour) && (StopTradingHour == 0 || dt.hour < StopTradingHour) && (maxSpread == 0 || maxSpread > SymbolInfoInteger(symbol.symbol, SYMBOL_SPREAD)))
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

int PositionsCount(string sym)
{
   int count = 0;
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
