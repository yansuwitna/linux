//+------------------------------------------------------------------+
//|            Trailing Step Logika Bertingkat (MQL5)               |
//+------------------------------------------------------------------+
#property strict
#include <Trade\Trade.mqh>

//--- Input parameter
input int StopLossPoints   = 2000;   // SL awal (Points)
input int TrailingStart    = 1000;   // Harga harus profit segini dulu (Points)
input int TrailingStep     = 500;   // SL naik setiap harga naik sejauh ini (Points)
input int MagicNumber      = 0;     // 0 untuk manual trade

CTrade trade;

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(PositionSelectByTicket(PositionGetTicket(i)))
        {
            if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
               PositionGetInteger(POSITION_MAGIC) == MagicNumber)
            {
                ApplySteppingTrailing(PositionGetTicket(i));
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Fungsi Logika Trailing Bertingkat                                |
//+------------------------------------------------------------------+
void ApplySteppingTrailing(ulong ticket)
{
    double bid         = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double ask         = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double openPrice   = PositionGetDouble(POSITION_PRICE_OPEN);
    double currentSL   = PositionGetDouble(POSITION_SL);
    double currentTP   = PositionGetDouble(POSITION_TP);
    long   type        = PositionGetInteger(POSITION_TYPE);
    
    double startDist   = TrailingStart * _Point;
    double stepDist    = TrailingStep * _Point;

    if(type == POSITION_TYPE_BUY)
    {
        // 1. Cek apakah profit sudah mencapai syarat Start
        if(bid >= openPrice + startDist)
        {
            // Hitung berapa kali "step" yang sudah dilalui dari harga open
            // Logika: SL baru = Harga saat ini - Jarak Step
            double potentialSL = bid - stepDist;
            
            // NORMALISASI agar SL naik secara bertahap (per 100 poin)
            // Ini memastikan SL tidak naik sedikit-sedikit, tapi per anak tangga
            double steppedSL = NormalizeDouble(MathFloor(potentialSL/stepDist)*stepDist, _Digits);

            // Modifikasi hanya jika steppedSL lebih tinggi dari SL sekarang
            if(steppedSL > currentSL + (1 * _Point) || currentSL == 0)
            {
                trade.PositionModify(ticket, steppedSL, currentTP);
            }
        }
        // 2. Pasang SL awal jika belum ada
        else if(currentSL == 0 && StopLossPoints > 0)
        {
            double initialSL = NormalizeDouble(openPrice - (StopLossPoints * _Point), _Digits);
            trade.PositionModify(ticket, initialSL, currentTP);
        }
    }
    else if(type == POSITION_TYPE_SELL)
    {
        if(ask <= openPrice - startDist)
        {
            double potentialSL = ask + stepDist;
            
            // Normalisasi turun untuk SELL
            double steppedSL = NormalizeDouble(MathCeil(potentialSL/stepDist)*stepDist, _Digits);

            if(steppedSL < currentSL - (1 * _Point) || currentSL == 0)
            {
                trade.PositionModify(ticket, steppedSL, currentTP);
            }
        }
        else if(currentSL == 0 && StopLossPoints > 0)
        {
            double initialSL = NormalizeDouble(openPrice + (StopLossPoints * _Point), _Digits);
            trade.PositionModify(ticket, initialSL, currentTP);
        }
    }
}