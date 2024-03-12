#include <Trade\Trade.mqh>
CTrade trade;

// input parameters
input double risk = 0.01;                    // risk
input ENUM_TIMEFRAMES timeFrame = PERIOD_H4; // grid time frame
int gridLength = 120;                        // grid period
input int inpPeriod = 6;                     // EMA period
input int maxGridAway = 6;                   // max grid away
input bool longTrade = true;                 // long trades
input bool shortTrade = false;               // short trades
input bool plot = false;                     // plot levels
input int InpMagicNumber = 666;              // magic number

// global variables
double bid, ask, spread, currentPrice, gridSize, gridLevels[8], close[], ema[], lastOpen;
int trendEMA = 0, copied, previousTrend = 0, trendCounter;

int OnInit()
{
  trade.SetExpertMagicNumber(InpMagicNumber);
  return (INIT_SUCCEEDED);
}

void OnTick()
{

  // if lastOpen is different from current close, set previousTrend to trendEMA
  if (lastOpen != iOpen(Symbol(), Period(), 1))
  {
    if (previousTrend != trendEMA)
    {
      trendCounter = 0;
    }
    else
    {
      trendCounter++;
    }
    previousTrend = trendEMA;
    lastOpen = iOpen(Symbol(), Period(), 1);
  }

  UpdateMarketInfo();
  UpdateGridLevels();

  if (spread > gridSize)
  {
    DeleteAllOrders();
    return;
  }

  if (inpPeriod > 0)
  {
    copied = CopyClose(Symbol(), 0, 0, inpPeriod, close);
    if (copied <= 0)
    {
      Print("Error copying close prices: ", GetLastError());
      return;
    }
    CalculateEMA(inpPeriod);
  }

  trendEMA = TrendEMA();

  CheckTrades();
  UpdateTakeProfitPositions();

  if (trendEMA == -1)
    DeleteAllBuyOrders();
  if (trendEMA == 1)
    DeleteAllSellOrders();

  DisplayComment();
  if (plot)
    DrawGridLines();

  CloseLosingPositions();
}

void CalculateEMA(int period)
{
  ArrayResize(ema, ArraySize(close));
  for (int i = 0; i < ArraySize(close); i++)
  {
    ema[i] = i > 0 ? ema[i - 1] + 2.0 / (1.0 + period) * (close[i] - ema[i - 1]) : close[i];
  }
}

int TrendEMA()
{
  if (inpPeriod == 0)
  {
    return 0;
  }
  if (ArraySize(close) < inpPeriod || ArraySize(ema) < inpPeriod)
  {
    Print("Not enough data for TrendEMA function. ArraySize(close): ", ArraySize(close), " ArraySize(ema): ", ArraySize(ema));
    return 0;
  }

  bool isBull = true;
  bool isBear = true;

  for (int i = 1; i <= inpPeriod; i += 1)
  {
    if (close[ArraySize(close) - i] <= ema[ArraySize(ema) - i])
      isBull = false;
    if (close[ArraySize(close) - i] >= ema[ArraySize(ema) - i])
      isBear = false;
  }

  if (close[ArraySize(close) - 1] <= ema[ArraySize(ema) - 1])
    isBull = false;
  if (close[ArraySize(close) - 1] >= ema[ArraySize(ema) - 1])
    isBear = false;

  if (isBull)
    return 1; // bull
  if (isBear)
    return -1; // bear
  return 0;    // ranging
}

void DeleteObjects()
{
  for (int i = 0; i < ArraySize(gridLevels); i++)
  {
    string name = IntegerToString(i);
    ObjectDelete(0, name);
  }
}

void DisplayComment()
{
  string commentText;
  commentText += "trend counter: " + IntegerToString(trendCounter) + "\n";
  commentText += "lastOpen: " + DoubleToString(lastOpen, Digits()) + "\n";
  commentText += "previousTrend: " + (previousTrend == 1 ? "bull" : previousTrend == -1 ? "bear"
                                                                                        : "range") +
                 "\n";
  commentText += "Symbol: " + Symbol() + "\n";
  commentText += "Trend: " + (trendEMA == 1 ? "bull" : trendEMA == -1 ? "bear"
                                                                      : "range") +
                 "\n";
  commentText += "Positions: " + IntegerToString(PositionsTotal()) + "\n";
  commentText += "Current Price: " + DoubleToString(currentPrice, Digits()) + "\n";
  commentText += "Spread: " + DoubleToString(spread, Digits()) + "\n";
  commentText += "gridSize: " + DoubleToString(gridSize, Digits()) + "\n";
  commentText += "gridTime: " + EnumToString(timeFrame) + "\n";
  commentText += "Grid Levels:\n";
  for (int i = 0; i < ArraySize(gridLevels); i++)
  {
    commentText += "Level " + IntegerToString(i) + ": " + DoubleToString(gridLevels[i], Digits()) + "\n";
  }
  Comment(commentText);
}

void UpdateMarketInfo()
{
  MqlTick Latest_Price;
  SymbolInfoTick(Symbol(), Latest_Price);
  bid = Latest_Price.bid;
  ask = Latest_Price.ask;
  spread = NormalizeDouble(ask - bid, Digits());
  currentPrice = NormalizeDouble((bid + ask) / 2, Digits());
}

void UpdateGridLevels()
{
  if (gridSize == 0)
  {
    gridSize = NormalizeDouble(AtrValue(), Digits());
    return;
  }
  double initialGridLevel = ceil(currentPrice / gridSize) * gridSize;
  if (gridLevels[0] == 0)
    gridLevels[0] = NormalizeDouble(initialGridLevel, Digits());
  if (gridLevels[1] == 0)
    gridLevels[1] = NormalizeDouble(gridLevels[0] - gridSize, Digits());
  if (gridLevels[2] == 0)
    gridLevels[2] = NormalizeDouble(gridLevels[0] + gridSize, Digits());
  if (gridLevels[3] == 0)
    gridLevels[3] = NormalizeDouble(gridLevels[1] - gridSize, Digits());
  if (gridLevels[4] == 0)
    gridLevels[4] = NormalizeDouble(gridLevels[2] + gridSize, Digits());
  if (gridLevels[5] == 0)
    gridLevels[5] = NormalizeDouble(gridLevels[3] - gridSize, Digits());
  if (gridLevels[6] == 0)
    gridLevels[6] = NormalizeDouble(gridLevels[4] + gridSize, Digits());
  if (gridLevels[7] == 0)
    gridLevels[7] = NormalizeDouble(gridLevels[5] - gridSize, Digits());

  // update grid levels when price moves
  if (currentPrice > gridLevels[2])
  {
    gridLevels[0] = gridLevels[4];
    gridLevels[1] = gridLevels[2];
    gridLevels[2] = 0;
    gridLevels[3] = 0;
    gridLevels[4] = 0;
    gridLevels[5] = 0;
    gridLevels[6] = 0;
    gridLevels[7] = 0;
    return;
  }
  if (currentPrice < gridLevels[3])
  {
    gridLevels[0] = gridLevels[5];
    gridLevels[1] = gridLevels[3];
    gridLevels[2] = 0;
    gridLevels[3] = 0;
    gridLevels[4] = 0;
    gridLevels[5] = 0;
    gridLevels[6] = 0;
    gridLevels[7] = 0;
    return;
  }
}

void DrawGridLines()
{
  for (int i = 0; i < ArraySize(gridLevels); i++)
  {
    string name = IntegerToString(i);
    ObjectCreate(0, name, OBJ_HLINE, 0, 0, gridLevels[i]);
    ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clrBlue);
  }
}

bool CheckExistence(string direction, double gridLevel)
{
  string gridLevelString = DoubleToString(gridLevel, Digits());
  for (int j = 0; j < PositionsTotal(); j++)
  {
    if (PositionGetTicket(j))
    {
      string comment = PositionGetString(POSITION_COMMENT);
      string commentParts[];
      int num = StringSplit(comment, ' ', commentParts);
      // Print("PositionsTotal: ", PositionsTotal() ," position comment: ", comment, " num: ", num, " PositionSelect(j) ", PositionSelect(j));
      if (num == 2 && commentParts[1] == gridLevelString && commentParts[0] == direction)
      {
        return true;
      }
    }
  }

  for (int k = 0; k < OrdersTotal(); k++)
  {
    if (OrderGetTicket(k))
    {
      string comment = OrderGetString(ORDER_COMMENT);
      string commentParts[];
      int num = StringSplit(comment, ' ', commentParts);
      // Print("OrdersTotal: ", OrdersTotal() ," order comment: ", comment, " num: ", num, " OrderSelect(k) ", OrderSelect(k));
      if (num == 2 && commentParts[1] == gridLevelString && commentParts[0] == direction)
      {
        return true;
      }
    }
  }

  return false;
}

void CheckTrades()
{
  if (gridSize == 0)
    return;
  for (int x = 0; x < ArraySize(gridLevels); x++)
  {
    for (int y = 0; y < ArraySize(gridLevels); y++)
    {
      if (x != y)
      {
        if (gridLevels[x] == gridLevels[y])
        {
          return;
        }
      }
    }
  }

  for (int i = 0; i < ArraySize(gridLevels) - 2; i++)
  {
    if (!CheckExistence("buy", gridLevels[i]) && longTrade)
    {
      OrderSend("buy", gridLevels[i], gridLevels[i] + gridSize);
    }

    if (!CheckExistence("sell", gridLevels[i]) && shortTrade)
    {
      OrderSend("sell", gridLevels[i], gridLevels[i] - gridSize);
    }
  }
}

void OrderSend(string direction, double price, double profit)
{
  string comment = direction + " " + DoubleToString(price, Digits());
  double lotSize = 0.01;
  if (direction == "buy" && (trendEMA == 1 || trendEMA == 0))
  {
    lotSize = OptimumLotSize(risk, profit - price);
    if (price < bid)
    {
      trade.BuyLimit(lotSize, price, Symbol(), 0, profit, ORDER_TIME_DAY, 0, comment);
    }
    if (price > ask)
    {
      trade.BuyStop(lotSize, price, Symbol(), 0, profit, ORDER_TIME_DAY, 0, comment);
    }
  }
  if (direction == "sell" && (trendEMA == -1 || trendEMA == 0))
  {
    lotSize = OptimumLotSize(risk, price - profit);
    if (price > ask)
    {
      trade.SellLimit(lotSize, price, Symbol(), 0, profit, ORDER_TIME_DAY, 0, comment);
    }
    if (price < bid)
    {
      trade.SellStop(lotSize, price, Symbol(), 0, profit, ORDER_TIME_DAY, 0, comment);
    }
  }
}

double AtrValue()
{
  double priceArray[];
  int atrDef = iATR(Symbol(), timeFrame, gridLength);
  ArraySetAsSeries(priceArray, true);
  CopyBuffer(atrDef, 0, 0, 1, priceArray);
  double atrValue = NormalizeDouble(priceArray[0], Digits());
  return atrValue;
}

void DeleteAllOrders()
{
  for (int i = 0; i < OrdersTotal(); i++)
  {
    if (OrderGetTicket(i))
    {
      string symbol = Symbol();
      string orderSymbol = OrderGetString(ORDER_SYMBOL);
      ulong ticket = OrderGetTicket(i);
      long magic = OrderGetInteger(ORDER_MAGIC);
      if (orderSymbol == symbol && magic == InpMagicNumber)
      {
        trade.OrderDelete(ticket);
      }
    }
  }
}

void DeleteAllBuyOrders()
{
  for (int i = 0; i < OrdersTotal(); i++)
  {
    if (OrderGetTicket(i))
    {
      string symbol = Symbol();
      string orderSymbol = OrderGetString(ORDER_SYMBOL);
      ulong ticket = OrderGetTicket(i);
      long magic = OrderGetInteger(ORDER_MAGIC);
      if (orderSymbol == symbol && magic == InpMagicNumber)
      {
        string comment = OrderGetString(ORDER_COMMENT);
        string commentParts[];
        int num = StringSplit(comment, ' ', commentParts);
        if (num > 0 && commentParts[0] == "buy")
        {
          trade.OrderDelete(ticket);
        }
      }
    }
  }
}

void DeleteAllSellOrders()
{
  for (int i = 0; i < OrdersTotal(); i++)
  {
    if (OrderGetTicket(i))
    {
      string symbol = Symbol();
      string orderSymbol = OrderGetString(ORDER_SYMBOL);
      ulong ticket = OrderGetTicket(i);
      long magic = OrderGetInteger(ORDER_MAGIC);
      if (orderSymbol == symbol && magic == InpMagicNumber)
      {
        string comment = OrderGetString(ORDER_COMMENT);
        string commentParts[];
        int num = StringSplit(comment, ' ', commentParts);
        if (num > 0 && commentParts[0] == "sell")
        {
          trade.OrderDelete(ticket);
        }
      }
    }
  }
}

void UpdateTakeProfitPositions()
{
  for (int i = 0; i < PositionsTotal(); i++)
  {
    if (PositionGetTicket(i))
    {
      string symbol = Symbol();
      ulong ticket = PositionGetTicket(i);
      string positionSymbol = PositionGetString(POSITION_SYMBOL);
      long magic = PositionGetInteger(POSITION_MAGIC);
      long positionType = PositionGetInteger(POSITION_TYPE);
      double entryPrice = NormalizeDouble(PositionGetDouble(POSITION_PRICE_OPEN), Digits());
      double takeProfit = NormalizeDouble(PositionGetDouble(POSITION_TP), Digits());
      double expectedLong = NormalizeDouble(entryPrice + gridSize, Digits());
      double expectedShort = NormalizeDouble(entryPrice - gridSize, Digits());

      if (positionSymbol == symbol && magic == InpMagicNumber)
      {
        if (positionType == POSITION_TYPE_BUY)
        {
          if (takeProfit != expectedLong)
          {
            trade.PositionModify(ticket, 0, expectedLong);
          }
        }
        if (positionType == POSITION_TYPE_SELL)
        {
          if (takeProfit != expectedShort)
          {
            trade.PositionModify(ticket, 0, expectedShort);
          }
        }
      }
    }
  }
}

double OptimumLotSize(double riskPercent, double stopPoints)
{
  double tickSize = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);
  double tickValue = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
  double lotStep = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
  double riskMoney = AccountInfoDouble(ACCOUNT_EQUITY) * riskPercent;
  double moneyLotStep = stopPoints / tickSize * tickValue * lotStep;
  double lots = MathRound(riskMoney / moneyLotStep) * lotStep;
  double minVol = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
  double maxVol = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);

  if (lots < minVol)
  {
    Print(lots, " > Adjusted to minimum volume > ", minVol);
    return minVol;
  }
  else if (lots > maxVol)
  {
    Print(lots, " > Adjusted to maximum volume > ", maxVol);
    return maxVol;
  }

  return NormalizeDouble(lots, 2);
}

void CloseLosingPositions()
{
  if (maxGridAway == 0)
    return;

  string symbol = Symbol();
  double slBuys = NormalizeDouble(currentPrice + (maxGridAway * gridSize), Digits());
  double slSells = NormalizeDouble(currentPrice - (maxGridAway * gridSize), Digits());

  for (int i = 0; i < PositionsTotal(); i++)
  {
    if (PositionGetTicket(i))
    {
      ulong ticket = PositionGetTicket(i);
      string positionSymbol = PositionGetString(POSITION_SYMBOL);
      long magic = PositionGetInteger(POSITION_MAGIC);
      long positionType = PositionGetInteger(POSITION_TYPE);
      double entryPrice = NormalizeDouble(PositionGetDouble(POSITION_PRICE_OPEN), Digits());

      if (positionSymbol != symbol || magic != InpMagicNumber)
        return;

      if (positionType == POSITION_TYPE_BUY && entryPrice > slBuys)
        trade.PositionClose(ticket);
      if (positionType == POSITION_TYPE_SELL && entryPrice < slSells)
        trade.PositionClose(ticket);
    }
  }
}
