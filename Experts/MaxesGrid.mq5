#include <Trade\Trade.mqh>
CTrade c_trade;
CPositionInfo c_position;

input group "general";
input int magicNumber = 8; // Magic number for the EA
input group "========= Symbol settings =========";
input string InpSymbol = "AUDUSD,EURUSD,GBPUSD,USDCAD,USDCHF,USDJPY,XAUUSD,US30,US500,UK100,DE40,JP225,STOXX50,F40,AUS200"; // Symbols
string symbols[];
input group "risk";
input double riskPercent = 1; // Risk percentage per trade
input group "range";
input int rangeDivider = 3;   // Range divider
input bool flipRange = false; // Flip the range
input group "filter";
input int rangePercentageFilter = 30;   // Range percentage filter
input double rangeFilterMultiplier = 0; // range divider multiplier filter (o=off)
input int divideFullRange = 0;          // use the full range and use this divider (0=off)
input group "plot";
input bool drawLevels = true; // levels on the chart
input bool drawInfo = false;  // Info on the chart

struct RANGE_STRUCT
{
   string symbol; // symbol
   double currentPrice, highestPrice, lowestPrice, takeProfit, stopLoss, currentLevel, initialLevel, higherHighDistance, lowerLowDistance, higherGridDistance, lowerGridDistance, higherLotSize, lowerLotSize;
   bool highRangeAllowed, lowRangeAllowed;
   int positionsTotal, positionsSell, positionsBuy;

   RANGE_STRUCT() : symbol(""), currentPrice(0), highestPrice(0), lowestPrice(0), takeProfit(0), stopLoss(0), currentLevel(0), initialLevel(0), higherHighDistance(0), lowerLowDistance(0), higherGridDistance(0), lowerGridDistance(0), higherLotSize(0), lowerLotSize(0), highRangeAllowed(false), lowRangeAllowed(false), positionsTotal(0), positionsSell(0), positionsBuy(0) {}
};
RANGE_STRUCT ranges[];

int OnInit()
{
   StringSplit(InpSymbol, ',', symbols);
   ArrayResize(ranges, ArraySize(symbols));
   for (int i = 0; i < ArraySize(symbols); i++)
   {
      string symbol = symbols[i];
      StringTrimRight(symbol); // remove trailing spaces
      StringTrimLeft(symbol);  // remove leading spaces
      StringToUpper(symbol);   // convert to uppercase
      symbols[i] = symbol;
      // check if symbol is in market watch
      if (!SymbolSelect(symbol, true))
      {
         Alert("Symbol " + symbol + " is not in market watch");
         return INIT_FAILED;
      }
      RANGE_STRUCT range;
      range.symbol = symbol;
      ranges[i] = range;
   }
   c_trade.SetExpertMagicNumber(magicNumber);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   ArrayFree(symbols);
   ArrayFree(ranges);
}

void OnTick()
{
   for (int i = 0; i < ArraySize(ranges); i++)
   {
      RANGE_STRUCT range = ranges[i];
      Cycle(range);
      ranges[i] = range;
      DrawLevels(range);
   }
}

void Cycle(RANGE_STRUCT &range)
{
   range.currentPrice = iClose(range.symbol, 0, 0);
   GetPositionCounts(range);

   if (range.positionsTotal == 0)
   {
      InitializeLevels(range);
      if (!range.highRangeAllowed || !range.lowRangeAllowed)
         return;
      OpenInitialPositions(range);
      return;
   }
   if (range.positionsBuy == 1 && range.positionsSell == 1)
      return;

   UpdateRangeAllowedFlags(range);

   if (range.highRangeAllowed && range.currentPrice >= range.takeProfit)
      OpenNewPositions(range.higherLotSize, range.currentLevel, range.higherGridDistance, range);
   if (range.lowRangeAllowed && range.currentPrice <= range.takeProfit)
      OpenNewPositions(range.lowerLotSize, range.currentLevel, range.lowerGridDistance, range);

   GetPositionCounts(range);
   UpdateLevels(range);

   if ((range.highRangeAllowed && range.currentPrice <= range.stopLoss) || (range.lowRangeAllowed && range.currentPrice >= range.stopLoss))
      CloseAllPositions(range);
}

void UpdateLevels(RANGE_STRUCT &range)
{
   if (range.highRangeAllowed)
   {
      range.takeProfit = range.initialLevel + (range.higherGridDistance * range.positionsSell);
      range.currentLevel = range.takeProfit - range.higherGridDistance;
      range.stopLoss = range.currentLevel - range.higherGridDistance;
   }
   else if (range.lowRangeAllowed)
   {
      range.takeProfit = range.initialLevel - (range.lowerGridDistance * range.positionsBuy);
      range.currentLevel = range.takeProfit + range.lowerGridDistance;
      range.stopLoss = range.currentLevel + range.lowerGridDistance;
   }
}

void InitializeLevels(RANGE_STRUCT &range)
{
   range.initialLevel = range.currentPrice;
   range.currentLevel = range.initialLevel;
   range.highestPrice = flipRange ? GetAllTimeLow(range) : GetAllTimeHigh(range);
   range.lowestPrice = flipRange ? GetAllTimeHigh(range) : GetAllTimeLow(range);
   range.higherHighDistance = MathAbs(range.highestPrice - range.initialLevel);
   range.lowerLowDistance = MathAbs(range.initialLevel - range.lowestPrice);
   range.highRangeAllowed = range.higherHighDistance > range.lowerLowDistance * ((double)rangePercentageFilter / 100);
   range.lowRangeAllowed = range.lowerLowDistance > range.higherHighDistance * ((double)rangePercentageFilter / 100);
   range.higherGridDistance = range.higherHighDistance / (double)rangeDivider;
   range.lowerGridDistance = range.lowerLowDistance / (double)rangeDivider;
   FilterRange(range);
   range.higherLotSize = CalculateLotSize(range.symbol, range.higherGridDistance);
   range.lowerLotSize = CalculateLotSize(range.symbol, range.lowerGridDistance);
   range.takeProfit = range.initialLevel + range.higherGridDistance;
   range.stopLoss = range.initialLevel - range.lowerGridDistance;
}

void FilterRange(RANGE_STRUCT &range)
{
   if (divideFullRange > 0)
   {
      double largestDistance = range.highestPrice - range.lowestPrice;
      double largestGridDistance = largestDistance / divideFullRange;
      range.higherHighDistance = largestDistance;
      range.lowerLowDistance = largestDistance;
      range.higherGridDistance = largestGridDistance;
      range.lowerGridDistance = largestGridDistance;
   }

   if ((range.highRangeAllowed && range.lowRangeAllowed) || rangeFilterMultiplier == 0)
      return;
   range.highRangeAllowed = true;
   range.lowRangeAllowed = true;
   double largestDistance = MathMax(range.higherHighDistance, range.lowerLowDistance);
   double largestGridDistance = largestDistance / (double)rangeDivider * rangeFilterMultiplier;
   range.higherHighDistance = largestDistance;
   range.lowerLowDistance = largestDistance;
   range.higherGridDistance = largestGridDistance;
   range.lowerGridDistance = largestGridDistance;
}

void OpenInitialPositions(RANGE_STRUCT &range)
{
   double higherTakeProfit = range.initialLevel + range.higherGridDistance;
   double lowerTakeProfit = range.initialLevel - range.lowerGridDistance;
   double firstLotSize = MathMin(range.higherLotSize, range.lowerLotSize);
   c_trade.Buy(firstLotSize, range.symbol, range.initialLevel, 0, higherTakeProfit);
   c_trade.Sell(firstLotSize, range.symbol, range.initialLevel, 0, lowerTakeProfit);
}

void UpdateRangeAllowedFlags(RANGE_STRUCT &range)
{
   range.highRangeAllowed = range.positionsBuy < range.positionsSell;
   range.lowRangeAllowed = range.positionsBuy > range.positionsSell;
}
void OpenNewPositions(double lotSize, double level, double gridDistance, RANGE_STRUCT &range)
{
   c_trade.Buy(lotSize, range.symbol, level, 0, level + gridDistance);
   c_trade.Sell(lotSize, range.symbol, level, 0, level - gridDistance);
}

double GetAllTimeHigh(RANGE_STRUCT &range)
{
   int nD1 = iBars(range.symbol, PERIOD_D1);
   if (nD1 == 0)
      return 0.;
   int iD1HH = iHighest(range.symbol, PERIOD_D1, MODE_HIGH);
   return iHigh(range.symbol, PERIOD_D1, iD1HH);
}

double GetAllTimeLow(RANGE_STRUCT &range)
{
   int nD1 = iBars(range.symbol, PERIOD_D1);
   if (nD1 == 0)
      return 0.;
   int iD1LL = iLowest(range.symbol, PERIOD_D1, MODE_LOW);
   return iLow(range.symbol, PERIOD_D1, iD1LL);
}

void CloseAllPositions(RANGE_STRUCT &range)
{
   for (int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if (PositionSelectByTicket(ticket) && c_position.Symbol() == range.symbol && c_position.Magic() == magicNumber)
      {
         c_trade.PositionClose(ticket);
      }
   }
}

void GetPositionCounts(RANGE_STRUCT &range)
{
   range.positionsTotal = range.positionsBuy = range.positionsSell = 0;
   for (int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if (PositionSelectByTicket(ticket) && PositionGetString(POSITION_SYMBOL) == range.symbol && PositionGetInteger(POSITION_MAGIC) == magicNumber)
      {
         range.positionsTotal++;
         if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            range.positionsBuy++;
         else if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
            range.positionsSell++;
      }
   }
}

double CalculateLotSize(string symbol, double riskDistance)
{
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   double minVol = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxVol = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);

   double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * riskPercent / 100;
   double moneyLotStep = riskDistance / tickSize * tickValue * lotStep;
   double lots = MathMax(MathFloor(riskMoney / moneyLotStep) * lotStep, minVol);

   return MathMin(MathMax(lots, minVol), maxVol);
}

void DrawLevels(RANGE_STRUCT &range)
{
   if (Symbol() != range.symbol)
      return;
   if (!drawLevels)
      return;

   DrawLevel("initialLevel", range.initialLevel, clrGold, 1);
   DrawLevel("currentLevel", range.currentLevel, clrWhite, 1);
   DrawLevel("highestPrice", range.highestPrice, clrGreen, 4);
   DrawLevel("lowestPrice", range.lowestPrice, clrRed, 4);
   DrawLevel("takeProfit", range.takeProfit, clrBlue, 2);
   DrawLevel("stopLoss", range.stopLoss, clrMagenta, 2);

   if (!drawInfo)
      return;
   Comment("Initial level: ", range.initialLevel, "\nHigher lot size: ", range.higherLotSize, "\nLower lot size: ", range.lowerLotSize, "\nHighest High: ", range.higherHighDistance, "\nLowest Low: ", range.lowerLowDistance, "\nhigher grid: ", range.higherGridDistance, "\nLower grid distance: ", range.lowerGridDistance, "\nHigh allowed: ", range.highRangeAllowed, "\nLow allowed: ", range.lowRangeAllowed, "\nPositions total: ", range.positionsTotal, "\nPositions buy: ", range.positionsBuy, "\nPositions sell: ", range.positionsSell, "\nCurrent price: ", range.currentPrice);
}

void DrawLevel(string name, double price, color clr, int width)
{
   ObjectCreate(0, name, OBJ_HLINE, 0, TimeCurrent(), price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
}