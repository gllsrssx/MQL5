// includes
#include <Trade\Trade.mqh>
#include <arrays/arrayLong.mqh>

// enumerations
enum ENUM_GRID_DIRECTION
{
    GRID_BUY,
    GRID_SELL
};

enum ENUM_GRID_MODE
{
    GRID_NEUTRAL,
    GRID_PROFIT,
    GRID_LOSS
};

// grid class
class CGrid : public CObject
{
private:
    // private variables
    ENUM_GRID_DIRECTION dir; // grid direction
    ENUM_GRID_MODE mode;     // grid mode
    CArrayLong tickets;      // array to store grid positions
    double last;             // last grid execution price
    int magicNumber;         // unique magic number for trades

public:
    // constructor
    CGrid(ENUM_GRID_DIRECTION direction, int magic) : dir(direction), magicNumber(magic)
    {
        mode = GRID_NEUTRAL;
    };

    // destructor
    ~CGrid() {};

    // public functions
    string ToString()
    {
        string txt;
        StringConcatenate(txt, EnumToString(dir), " ", EnumToString(mode), " > Tickets: ", tickets.Total(), "  Last: ", DoubleToString(last, _Digits));
        return txt;
    }

    void OnTickEvent()
    {
        double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

        // open first position if tickets array is empty
        if (tickets.Total() == 0)
        {
            execute();
        }
        else
        {
            // open more positions if next trigger level is hit
            if (dir == GRID_BUY)
            {
                handleBuyGrid(bid);
            }
            else if (dir == GRID_SELL)
            {
                handleSellGrid(bid);
            }
        }
    }

    void OnTradeTransactionEvent(const MqlTradeTransaction &trans,
                                 const MqlTradeRequest &request,
                                 const MqlTradeResult &result)
    {
        // select deal
        if (trans.type == TRADE_TRANSACTION_DEAL_ADD)
        {
            handleDealAdd(trans);
        }
    }

    void TrailLosingGrid()
    {
        double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        if (mode == GRID_LOSS)
        {
            if ((dir == GRID_BUY && bid > last) || (dir == GRID_SELL && bid < last))
            {
                closeAllPositions();
                mode = GRID_NEUTRAL;
            }
        }
    }

    void TrailWinningGrid()
    {
        double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        double trailingDistance = GridPercentProfit * TrailingPercent / 100;

        if (mode == GRID_PROFIT)
        {
            if ((dir == GRID_BUY && bid < last - last * trailingDistance / 100) ||
                (dir == GRID_SELL && bid > last + last * trailingDistance / 100))
            {
                closeAllPositions();
                mode = GRID_NEUTRAL;
            }
        }
    }

private:
    // private functions
    void execute()
    {
        CTrade trade;
        double lots = calculateLotSize();

        trade.SetExpertMagicNumber(magicNumber);

        if (dir == GRID_BUY)
        {
            trade.Buy(lots, _Symbol, 0, 0, 0, "");
        }
        else if (dir == GRID_SELL)
        {
            trade.Sell(lots, _Symbol, 0, 0, 0, "");
        }

        // update last grid execution price
        last = SymbolInfoDouble(_Symbol, SYMBOL_BID);

        // store new position ticket in tickets array
        ulong order = trade.ResultOrder();
        if (order > 0)
        {
            tickets.Add(order);
        }
    }

    double calculateLotSize()
    {
        double lots = Lots;
        if (mode == GRID_PROFIT)
        {
            lots *= lotsProfit[MathMin(ArraySize(lotsProfit) - 1, tickets.Total())];
        }
        else if (mode == GRID_LOSS)
        {
            lots *= lotsLoss[MathMin(ArraySize(lotsLoss) - 1, tickets.Total())];
        }
        return lots;
    }

    void handleBuyGrid(double bid)
    {
        if (mode == GRID_NEUTRAL || mode == GRID_PROFIT)
        {
            if (bid > last + last * GridPercentProfit / 100)
            {
                execute();
                mode = GRID_PROFIT;
            }
        }
        if (mode == GRID_NEUTRAL || mode == GRID_LOSS)
        {
            if (bid < last - last * GridPercentLoss / 100)
            {
                execute();
                mode = GRID_LOSS;
            }
        }
    }

    void handleSellGrid(double bid)
    {
        if (mode == GRID_NEUTRAL || mode == GRID_PROFIT)
        {
            if (bid < last - last * GridPercentProfit / 100)
            {
                execute();
                mode = GRID_PROFIT;
            }
        }
        if (mode == GRID_NEUTRAL || mode == GRID_LOSS)
        {
            if (bid > last + last * GridPercentLoss / 100)
            {
                execute();
                mode = GRID_LOSS;
            }
        }
    }

    void handleDealAdd(const MqlTradeTransaction &trans)
    {
        if (HistorySelect(TimeCurrent() - 100, TimeCurrent() + 100))
        {
            CDealInfo deal;
            deal.Ticket(trans.deal);

            if (deal.Entry() == DEAL_ENTRY_IN)
            {
                modifyPositionAfterEntry(deal);
            }
            else if (deal.Entry() == DEAL_ENTRY_OUT)
            {
                closePositionAfterExit(deal);
            }
        }
    }

    void modifyPositionAfterEntry(const CDealInfo &deal)
    {
        if (mode != GRID_NEUTRAL)
        {
            double tp = 0;
            double sl = 0;

            if (deal.DealType() == DEAL_TYPE_BUY)
            {
                if (dir == GRID_SELL)
                {
                    return;
                }
                if (mode == GRID_PROFIT)
                {
                    sl = calculateStopLoss();
                }
                else if (mode == GRID_LOSS)
                {
                    tp = calculateTakeProfit();
                }
            }
            else if (deal.DealType() == DEAL_TYPE_SELL)
            {
                if (dir == GRID_BUY)
                {
                    return;
                }
                if (mode == GRID_PROFIT)
                {
                    sl = calculateStopLoss();
                }
                else if (mode == GRID_LOSS)
                {
                    tp = calculateTakeProfit();
                }
            }

            modifyAllPositions(sl, tp);
        }
    }

    double calculateStopLoss()
    {
        return last - last * slProfit[MathMin(ArraySize(slProfit) - 1, tickets.Total() - 1)] / 100;
    }

    double calculateTakeProfit()
    {
        return last + last * tpLoss[MathMin(ArraySize(tpLoss) - 1, tickets.Total() - 1)] / 100;
    }

    void modifyAllPositions(double sl, double tp)
    {
        CTrade trade;
        for (int i = tickets.Total() - 1; i >= 0; i--)
        {
            CPositionInfo pos;
            if (pos.SelectByTicket(tickets.At(i)))
            {
                trade.PositionModify(pos.Ticket(), sl, tp);
            }
        }
    }

    void closePositionAfterExit(const CDealInfo &deal)
    {
        if ((deal.DealType() == DEAL_TYPE_BUY && dir == GRID_BUY) || (deal.DealType() == DEAL_TYPE_SELL && dir == GRID_SELL))
        {
            return;
        }

        closeAllPositions();
        if (tickets.Total() == 0)
        {
            mode = GRID_NEUTRAL;
        }
    }

    void closeAllPositions()
    {
        CTrade trade;
        for (int i = tickets.Total() - 1; i >= 0; i--)
        {
            CPositionInfo pos;
            if (pos.SelectByTicket(tickets.At(i)))
            {
                trade.PositionClose(pos.Ticket());
            }
        }
        tickets.Clear();
    }
};

// input variables
input double Lots = 0.1;
input double GridPercentProfit = 1.0;
input double GridPercentLoss = 3.0;
input bool IsChartComment = true;
input int MagicNumberBuy = 123456;
input int MagicNumberSell = 654321;
input double TrailingPercent = 50.0; // New input for trailing percentage

CGrid gridBuy(GRID_BUY, MagicNumberBuy);
CGrid gridSell(GRID_SELL, MagicNumberSell);

// arrays for lot scaling
double lotsProfit[] = {1, 1, 2, 4, 8, 16, 32};
double lotsLoss[] = {1, 1, 2, 3, 5, 8, 13, 21, 34};

// arrays for sl and tp level
double slProfit[] = {0.5};
double tpLoss[] = {0.5, 1.0, 3.5, 6.0, 12.0};

int OnInit()
{
    return (INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
}

void OnTick()
{
    gridBuy.OnTickEvent();
    gridSell.OnTickEvent();
    gridBuy.TrailLosingGrid();
    gridSell.TrailLosingGrid();
    gridBuy.TrailWinningGrid();
    gridSell.TrailWinningGrid();
}

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
    gridBuy.OnTradeTransactionEvent(trans, request, result);
    gridSell.OnTradeTransactionEvent(trans, request, result);

    if (IsChartComment)
    {
        Comment("\n\n", gridBuy.ToString(), "\n", gridSell.ToString());
    }
}