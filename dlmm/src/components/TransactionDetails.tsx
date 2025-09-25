import { ChevronDown, Zap, Clock, Edit } from "lucide-react";
import { Button } from "@/components/ui/button";

const TransactionDetails = () => {
  return (
    <div className="mt-6 pt-4 border-t border-border space-y-3">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <span className="text-sm text-muted-foreground">Route</span>
          <div className="w-1 h-1 rounded-full bg-muted-foreground"></div>
        </div>
        <Button variant="ghost" size="sm" className="h-6 px-2 py-1 text-xs bg-accent text-accent-foreground hover:bg-accent/80 flex items-center gap-1">
          <Zap className="w-3 h-3" />
          Best Rate
          <span className="text-muted-foreground">- 1 min</span>
          <ChevronDown className="w-3 h-3" />
        </Button>
      </div>

      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <span className="text-sm text-muted-foreground">Minimum Received</span>
          <div className="w-1 h-1 rounded-full bg-muted-foreground"></div>
        </div>
        <div className="flex items-center gap-1 text-sm text-muted-foreground">
          <Clock className="w-3 h-3" />
          <span>~ 1 min</span>
          <Edit className="w-3 h-3" />
        </div>
      </div>

      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <span className="text-sm text-muted-foreground">Rate</span>
          <div className="w-1 h-1 rounded-full bg-muted-foreground"></div>
        </div>
        <div className="flex items-center gap-1 text-sm text-muted-foreground">
          <Clock className="w-3 h-3" />
          <span>~ 1 min</span>
          <Edit className="w-3 h-3" />
        </div>
      </div>

      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <span className="text-sm text-muted-foreground">Network Fee</span>
          <div className="w-1 h-1 rounded-full bg-muted-foreground"></div>
        </div>
        <span className="text-sm text-muted-foreground">0.000518 SOL ($0.1066)</span>
      </div>
    </div>
  );
};

export default TransactionDetails;