// includes
#include <Trade\Trade.mqh>
#include <arrays/arrayLong.mqh>

// input variables
input long MagicNumber = 123456;       // magic number for trades
input double RiskPercent = 1.0;        // risk percentage per trade
input double GridPercentInitial = 1.0; // initial grid distance in percentage
input bool IsChartComment = true;      // show grid information on chart

// enumerations for aggressiveness levels
enum ENUM_AGGRESSIVENESS
{
    AGGRESSIVENESS_VERY_LOW = 0.1,
    AGGRESSIVENESS_LOW = 0.2,
    AGGRESSIVENESS_MEDIUM_LOW = 0.5,
    AGGRESSIVENESS_MEDIUM = 1.0,
    AGGRESSIVENESS_MEDIUM_HIGH = 2.0,
    AGGRESSIVENESS_HIGH = 5.0,
    AGGRESSIVENESS_VERY_HIGH = 10.0
};
input ENUM_AGGRESSIVENESS AggressivenessProfit = AGGRESSIVENESS_MEDIUM; // aggressiveness of winning grid
input ENUM_AGGRESSIVENESS AggressivenessLoss = AGGRESSIVENESS_MEDIUM;   // aggressiveness of losing grid

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
    ENUM_GRID_DIRECTION direction; // grid direction
    ENUM_GRID_MODE mode;           // grid mode
    CArrayLong tickets;            // array to store grid positions
    int magic;                     // unique magic number for trades
    double lastGridPrice;          // last grid execution price
    double initialGridDistance;    // initial grid distance
    double gridDistance;           // current grid distance
    double lotSizeInitial;         // Initial lot size
    double lotSizeCurrent;         // current lot size
    double aggressiveness;         // aggressiveness of increases

public:
    // constructor
    CGrid(ENUM_GRID_DIRECTION direction, int magic, double initialDistance, double initialLot, double aggress) : direction(direction), magic(magic), initialGridDistance(initialDistance), gridDistance(initialDistance), lotSizeInitial(initialLot), lotSizeCurrent(initialLot), aggressiveness(aggress)
    {
        mode = GRID_NEUTRAL;
    };

    // destructor
    ~CGrid() {};

    // public functions
    string ToString()
    {
        string txt;
        StringConcatenate(txt, EnumToString(direction), " ", EnumToString(mode), " > Tickets: ", tickets.Total(), "  Last: ", DoubleToString(lastGridPrice, Digits()));
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
            // if losing grid goes in profit close all positions
            if ((dir == GRID_BUY && bid > last + initialGridDistance) || (dir == GRID_SELL && bid < last - initialGridDistance))
            {
                closeAllPositions(); // only close positions of the losing grid
                mode = GRID_NEUTRAL;
            }
        }
    }

    void TrailWinningGrid()
    {
        double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        double trailingDistance = initialGridDistance * TrailingPercent / 100;

        if (mode == GRID_PROFIT)
        {
            if ((dir == GRID_BUY && bid < last - trailingDistance) ||
                (dir == GRID_SELL && bid > last + trailingDistance))
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

        if (dir == GRID_BUY)
        {
            trade.SetExpertMagicNumber(1 + magicNumber);
            trade.Buy(lotSize);
        }
        else if (dir == GRID_SELL)
        {
            trade.SetExpertMagicNumber(0 + magicNumber);
            trade.Sell(lotSize);
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

    void handleBuyGrid(double bid)
    {
        if (mode == GRID_NEUTRAL || mode == GRID_PROFIT)
        {
            if (bid > last + gridDistance)
            {
                execute();
                mode = GRID_PROFIT;
                lotSize *= 1 + aggressiveness / 100;
            }
        }
        if (mode == GRID_NEUTRAL || mode == GRID_LOSS)
        {
            if (bid < last - gridDistance)
            {
                execute();
                mode = GRID_LOSS;
                gridDistance *= 1 + aggressiveness / 100;
                lotSize *= 1 + aggressiveness / 100;
            }
        }
    }

    void handleSellGrid(double bid)
    {
        if (mode == GRID_NEUTRAL || mode == GRID_PROFIT)
        {
            if (bid < last - gridDistance)
            {
                execute();
                mode = GRID_PROFIT;
                lotSize *= 1 + aggressiveness / 100;
            }
        }
        if (mode == GRID_NEUTRAL || mode == GRID_LOSS)
        {
            if (bid > last + gridDistance)
            {
                execute();
                mode = GRID_LOSS;
                gridDistance *= 1 + aggressiveness / 100;
                lotSize *= 1 + aggressiveness / 100;
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

CGrid gridBuy(GRID_BUY, MagicNumberBuy, GridPercentProfit, Lots, AggressivenessProfit);
CGrid gridSell(GRID_SELL, MagicNumberSell, GridPercentLoss, Lots, AggressivenessLoss);

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